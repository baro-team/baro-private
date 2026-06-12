# Backup and Recovery

## 문서 목적

이 문서는 MinIO 기반 backup 구조와 복원 시 지켜야 할 절차를 설명합니다. 실제 복원은 운영 데이터와 cluster 상태에 영향을 줄 수 있으므로 점검 시간과 rollback 계획을 확보한 후 수행합니다.

## Backup 구조

| 대상 | 방식 | 실행 위치 | 주기 | 보존 |
|---|---|---|---|---|
| TimescaleDB | `pg_dump` 후 gzip 및 MinIO 업로드 | K3s CronJob | 매일 | 3일 |
| K3s SQLite | `state.db` 복사 후 gzip 및 MinIO 업로드 | `k3s-master` cron | 매일 | 3일 |
| Terraform state | OpenStack/K3s state 복사 및 MinIO 업로드 | `openstack-aio` cron | 매일 | 3일 |
| Harbor | Bucket만 준비됨 | 미설정 | 미설정 | 3일 |

MinIO는 `backup` VM에서 실행됩니다. Credential, lifecycle rule ID 및 내부 접근 정보는 공개 문서에 기록하지 않습니다.

## 공통 원칙

- 복원 전에 현재 상태를 별도 backup합니다.
- 최신 파일이라는 이유만으로 바로 복원하지 않고 크기, 생성 시간 및 대상 환경을 확인합니다.
- 복원 명령은 maintenance window에서 실행합니다.
- Secret과 state 파일을 terminal log나 Git에 남기지 않습니다.
- 복원 후 서비스 상태와 데이터 정합성을 확인합니다.

## TimescaleDB 복원

복원 흐름:

```text
MinIO backup 선택
  -> K3s master로 다운로드
  -> TimescaleDB Pod에 전달
  -> 대상 DB에 복원
  -> 데이터 정합성 확인
```

점검 항목:

- TimescaleDB Pod와 PVC가 정상인지
- Backup 파일이 정상적으로 압축 해제되는지
- 대상 database와 schema가 올바른지
- 복원 전후 기준 query 결과가 일치하는지
- Airflow 등 연결 서비스가 정상인지

운영 데이터 삭제를 포함한 복원 테스트는 별도 테스트 데이터 또는 격리된 환경에서 수행하는 것을 권장합니다.

## K3s SQLite 복원

K3s control plane을 중지한 후 `/var/lib/rancher/k3s/server/db/state.db`를 backup 파일로 교체합니다.

복원 전 필수 조치:

1. 현재 `state.db` 별도 보관
2. K3s service 중지
3. 파일 소유권과 권한 확인
4. Backup state로 교체
5. K3s service 시작

복원 후 확인:

```bash
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
sudo kubectl get svc -A
sudo kubectl get pvc -A
```

Node 3대와 주요 Pod가 정상 상태가 아니면 원래 `state.db`로 rollback합니다.

## Terraform State 복원

Terraform state 복원은 실제 인프라를 변경하지 않고 state와 실제 리소스의 관계를 복구하는 작업입니다.

복원 절차:

1. 현재 state 파일 별도 보관
2. Backup state의 대상과 생성 시점 확인
3. Local backend 경로에 backup state 배치
4. `terraform plan` 실행
5. 예상하지 않은 create, replace 또는 destroy가 없는지 확인

State 복원 직후 `terraform apply`를 실행하지 않습니다. Plan이 실제 인프라와 일치하지 않으면 원래 state로 rollback하고 import 또는 state 조정 방식을 검토합니다.

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

- Harbor backup workflow는 아직 설정되지 않았습니다.
- Backup 작업과 MinIO lifecycle은 Terraform 관리 범위 밖입니다.
- Local-path volume은 node 종속성이 있으므로 VM 또는 node 장애 복구 시 별도 검토가 필요합니다.

## 관련 문서

- [K3s Cluster](k3s-cluster.md)
- [Terraform and CI/CD](terraform-cicd.md)
- [Operation Guide](operation-guide.md)
