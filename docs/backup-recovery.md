# Backup and Recovery

## 문서 목적

이 문서는 MinIO 기반 backup 구조와 복원 시 지켜야 할 절차를 설명합니다. 실제 복원은 운영 데이터와 cluster 상태에 영향을 줄 수 있으므로 점검 시간과 rollback 계획을 확보한 후 수행합니다.

## Backup 구조

| 대상 | 방식 | 실행 위치 | 주기 | 보존 |
|---|---|---|---|---|
| TimescaleDB | `pg_dump` 후 gzip 및 MinIO 업로드 | K3s CronJob | 매일 KST 04:00 | 3일 |
| K3s SQLite | `sqlite3 .backup` 후 gzip 및 MinIO 업로드 | `k3s-master` cron | 매일 KST 04:30 | 3일 |
| Terraform state | OpenStack/K3s state 복사 및 MinIO 업로드 | `openstack-aio` cron | 매일 KST 05:00 | 3일 |

MinIO는 `backup` VM에서 실행됩니다. Credential, lifecycle rule ID 및 내부 접근 정보는 공개 문서에 기록하지 않습니다.

## MinIO 버킷 구성

| 버킷 | 용도 | 보존 | 자동 삭제 |
|---|---|---|---|
| `timescaledb-backup` | TimescaleDB 전체 DB 덤프 | 3일 | lifecycle policy |
| `k3s-etcd-backup` | K3s SQLite 스냅샷(기존 bucket name 유지) | 3일 | lifecycle policy |
| `terraform-state-backup` | Terraform 상태 파일 | 3일 | lifecycle policy |

보존 정책 3일의 근거: pg_dump는 전체 백업이므로 최신 파일 1개로 전체 복원이 가능합니다. 3일이면 늦은 발견에도 대응 가능하고 backup VM의 100 GB 디스크에 부담이 없습니다.

## 공통 원칙

- 복원 전에 현재 상태를 별도 backup합니다.
- 최신 파일이라는 이유만으로 바로 복원하지 않고 크기, 생성 시간 및 대상 환경을 확인합니다.
- 복원 명령은 maintenance window에서 실행합니다.
- Secret과 state 파일을 terminal log나 Git에 남기지 않습니다.
- 복원 후 서비스 상태와 데이터 정합성을 확인합니다.

## TimescaleDB 백업 및 복원

### 백업 방식

K3s CronJob(namespace `database`, name `timescaledb-backup`)이 매일 KST 04:00(UTC 19:00)에 실행됩니다. postgres:17 이미지 기반 Pod가 pg_dump로 전체 데이터베이스를 덤프한 뒤 gzip 압축하고 mc로 MinIO에 업로드합니다. 파일 형식은 `timescaledb_YYYYMMDD_HHMMSS.sql.gz`입니다.

### 복원 흐름

```text
MinIO backup 선택
  -> K3s master로 다운로드
  -> TimescaleDB Pod에 전달
  -> 대상 DB에 복원
  -> 데이터 정합성 확인
```

### 복원 점검 항목

- TimescaleDB Pod와 PVC가 정상인지
- Backup 파일이 정상적으로 압축 해제되는지
- 대상 database와 schema가 올바른지
- 복원 전후 기준 query 결과가 일치하는지
- Airflow 등 연결 서비스가 정상인지

### 복원 시 참고사항

pg_dump 백업은 전체 DB를 복원하는 SQL입니다. DB 전체가 손실된 경우에는 빈 DB를 다시 만든 뒤 전체 dump를 복원하는 방식이 가장 안전합니다. 특정 table이나 일부 row만 복구해야 하는 경우에는 운영 DB에 바로 덮어쓰기보다 임시 DB에 먼저 복원한 뒤 필요한 데이터만 이관합니다.

## K3s SQLite 백업 및 복원

### 백업 방식

K3s 마스터(ubuntu 사용자 crontab)에서 매일 KST 04:30(UTC 19:30)에 실행됩니다. `sqlite3 .backup` 명령으로 WAL(Write-Ahead Log)을 포함한 일관된 복사본을 생성합니다. 이 방식은 K3s가 실행 중이어도 안전합니다. 생성된 파일을 gzip 압축한 뒤 mc로 MinIO에 업로드합니다. 파일 형식은 `k3s-state_YYYYMMDD_HHMMSS.db.gz`입니다.

### 백업 방식 선택 이유

SQLite가 WAL 모드로 동작할 때 세 개의 파일이 함께 사용됩니다. `state.db`는 메인 데이터베이스이고, `state.db-wal`은 아직 메인 DB에 병합되지 않은 최신 변경사항을 담는 Write-Ahead Log이며, `state.db-shm`은 WAL의 인덱스 역할을 하는 Shared Memory 파일입니다. `sudo cp`로 state.db만 복사하면 WAL의 미커밋 데이터가 누락되어 불완전한 백업이 됩니다. `sqlite3 .backup` 명령은 WAL을 자동으로 통합하여 단일 파일로 일관된 복사본을 만들어 줍니다.

### 복원 절차

1. 현재 `state.db` 별도 보관
2. K3s service 중지
3. Backup state로 교체
4. `state.db-wal`과 `state.db-shm` 삭제
5. K3s service 시작

### 복원 시 WAL/SHM 삭제가 필수인 이유

복원 시 state.db만 교체하고 기존 state.db-wal과 state.db-shm을 남겨두면, 이전 WAL 파일과 새 state.db의 내용이 불일치합니다. SQLite가 이 불일치 상태의 DB를 열려고 하면서 K3s가 `Bootstrap key already locked` 에러로 시작하지 못합니다. 반드시 두 파일을 삭제하여 SQLite가 state.db 파일만으로 깨끗하게 시작하도록 해야 합니다.

### 복원 후 확인

```bash
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
sudo kubectl get svc -A
sudo kubectl get pvc -A
```

Node 3대와 주요 Pod가 정상 상태가 아니면 원래 `state.db`로 rollback합니다.

## Terraform State 백업 및 복원

### 백업 방식

메인 서버(baro 사용자 crontab)에서 매일 KST 05:00(UTC 20:00)에 실행됩니다. OpenStack과 K3s 상태 파일을 타임스탬프를 붙여 MinIO `terraform-state-backup` 버킷에 업로드합니다. 파일 형식은 `openstack_YYYYMMDD_HHMMSS.tfstate`와 `k3s_YYYYMMDD_HHMMSS.tfstate`입니다.

### 백업이 필요한 이유

Terraform 상태 파일이 손실되면 Terraform이 기존 리소스를 인식하지 못합니다. 다음 apply 시 이미 존재하는 리소스를 중복 생성하려고 시도하거나, 수십 개 리소스에 대해 수동으로 `terraform import`를 해야 합니다.

### 복원 절차

1. 현재 state 파일 별도 보관
2. Backup state의 대상과 생성 시점 확인
3. Local backend 경로에 backup state 배치
4. `terraform plan` 실행
5. 예상하지 않은 create, replace 또는 destroy가 없는지 확인

State 복원 직후 `terraform apply`를 실행하지 않습니다. Plan이 실제 인프라와 일치하지 않으면 원래 state로 rollback하고 import 또는 state 조정 방식을 검토합니다.

## 비상 접근

메인 서버 장애 시 보조 서버에서 backup VM에 콘솔로 접근하여 백업 데이터를 확인할 수 있습니다. 보조 서버에 SSH 접속한 뒤 virsh console로 backup VM에 진입합니다. mc 명령으로 세 버킷의 백업 파일을 확인합니다.

메인 서버가 완전히 꺼져도 보조 서버의 VM(harbor, backup)은 컴퓨트 노드의 libvirt/KVM 위에서 독립적으로 동작하므로 백업 데이터에 접근할 수 있습니다. 단, OpenStack API는 사용할 수 없고 virsh 콘솔로만 접근 가능합니다.

## 복원 테스트

정기 복원 테스트에는 다음 항목을 기록합니다.

| 항목 | 기록 내용 |
|---|---|
| Backup 생성 시각 | 대상별 최신 backup 시각 |
| 복원 시작 및 종료 시각 | 실제 복원 소요 시간 |
| 검증 기준 | Query 결과, node 및 Pod 상태, Terraform plan |
| Rollback 여부 | Rollback 사유와 결과 |
| 발견 문제 | 누락 파일, 권한, 경로 및 credential 문제 |

물리 서버 재부팅 복구 테스트는 현장 접근이 가능한 상태에서 수행하며, `br-ex`, DNAT, VPN, VM, K3s 및 backup 작업을 순서대로 확인합니다.

## 현재 제한사항

- Harbor backup은 설정되지 않았습니다.
- Backup 작업과 MinIO lifecycle은 Terraform 관리 범위 밖입니다.
- Local-path volume은 node 종속성이 있으므로 VM 또는 node 장애 복구 시 별도 검토가 필요합니다.

## 관련 문서

- [K3s Cluster](k3s-cluster.md)
- [Terraform and CI/CD](terraform-cicd.md)
- [Operation Guide](operation-guide.md)
