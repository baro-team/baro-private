# K3s Cluster

## 문서 목적

이 문서는 OpenStack VM 위에서 운영되는 K3s cluster와 Terraform으로 관리하는 Helm release를 설명합니다.

## Cluster 구성

| Node | IP | 역할 | 주요 workload |
|---|---|---|---|
| `k3s-master` | `10.10.10.170` | 단일 control plane | Prometheus, Grafana, Alertmanager |
| `k3s-worker-1` | `10.10.10.165` | Worker | TimescaleDB, backup CronJob |
| `k3s-worker-2` | `10.10.10.195` | Worker | Airflow |

주요 설정:

- CNI: Flannel VXLAN
- Cluster DB: SQLite
- StorageClass: `local-path`
- Traefik 및 ServiceLB 비활성화
- 외부 접근: NodePort와 host DNAT

## Workload 배치

Monitoring workload는 `role=monitoring` label이 있는 master에 배치됩니다. TimescaleDB와 Airflow는 hostname 기반 `nodeSelector`를 사용합니다.

| Workload | 배치 기준 |
|---|---|
| Grafana, Prometheus, Alertmanager, kube-state-metrics | `role=monitoring` |
| TimescaleDB | `kubernetes.io/hostname=k3s-worker-1` |
| Airflow component | `kubernetes.io/hostname=k3s-worker-2` |
| Node exporter | Toleration을 사용해 모든 node |

Node label은 Terraform 관리 범위 밖이며 수동으로 유지합니다.

## Helm Release

| Release | Namespace | Chart | 역할 |
|---|---|---|---|
| `monitoring` | `monitoring` | kube-prometheus-stack `84.1.2` | Prometheus 및 Grafana |
| `cloudwatch-exporter` | `monitoring` | prometheus-cloudwatch-exporter `0.28.1` | AWS dev 지표 수집 |
| `blackbox-exporter` | `monitoring` | prometheus-blackbox-exporter `11.12.0` | HTTP/TCP 외부 헬스체크 |
| `timescaledb` | `database` | TimescaleDB `0.11.2` | PostgreSQL 17 기반 데이터 저장 |
| `airflow` | `airflow` | Apache Airflow `1.21.0` | Workflow 실행 및 관리 |

Airflow는 metadata DB로 TimescaleDB를 사용하므로 Terraform에서 `depends_on = [helm_release.timescaledb]`가 설정되어 있습니다.

## Monitoring

- Grafana NodePort: `30300`
- Prometheus NodePort: `30900`
- Prometheus external URL: `http://192.168.203.187:30900`
- Prometheus retention: `7d`
- Grafana admin password는 Terraform sensitive variable로 주입
- cloudwatch-exporter AWS 자격 증명은 Kubernetes Secret `monitoring/cloudwatch-exporter-aws-credentials`로 주입합니다.
- Secret data key는 chart template 기준 `access_key`, `secret_key`를 사용합니다.
- blackbox-exporter는 `http_2xx`, `tcp_connect` 모듈을 사용합니다. 실제 probe target은 `helm-values/blackbox-exporter.yaml`에서 endpoint 확정 후 추가합니다.
- 기존 Prometheus/Grafana 설정은 변경하지 않고 exporter Helm release만 추가합니다.

## TimescaleDB

- Image: `timescale/timescaledb:2.23.1-pg17`
- Service type: NodePort
- Persistence: `10Gi`, `local-path`
- PostgreSQL password는 Terraform sensitive variable로 주입
- Backup CronJob은 Terraform 관리 범위 밖

현재 chart는 NodePort 번호 설정을 지원하지 않아 Kubernetes가 번호를 자동 할당합니다. Release 재설치 후 NodePort가 달라지면 host DNAT 대상도 변경해야 합니다.

## Airflow

- Executor: `LocalExecutor`
- Custom image source: 내부 Harbor
- API server NodePort: `30800`
- DAG: Git sync 사용
- Metadata DB: TimescaleDB
- Internal PostgreSQL, Redis, Flower 및 StatsD 비활성화

Airflow DB password는 Terraform sensitive variable로 주입합니다.

## Terraform 관리

K3s Helm release는 [`terraform/k3s`](../terraform/k3s)에서 관리합니다.

| 파일 | 관리 대상 |
|---|---|
| `monitoring.tf` | Monitoring release와 Grafana secret 주입 |
| `helm-values/cloudwatch-exporter.yaml` | CloudWatch exporter 설정 |
| `helm-values/blackbox-exporter.yaml` | Blackbox exporter 설정 |
| `timescaledb.tf` | TimescaleDB release와 DB secret 주입 |
| `airflow.tf` | Airflow release와 DB secret 주입 |
| `helm-values/` | Secret을 제외한 release 설정 |
| `variables.tf` | Chart version과 sensitive variable |
| `versions.tf` | Helm provider와 local backend |

## 관리 범위 밖

- K3s 설치 및 host config
- Node label
- Harbor insecure registry 설정
- TimescaleDB backup CronJob
- K3s SQLite backup cron
- NodePort 변경 시 host DNAT 갱신

## 변경 시 주의사항

- Helm release 삭제 후 재생성은 NodePort와 local-path PVC에 영향을 줄 수 있습니다.
- NodeSelector 변경 전 대상 node의 자원과 label을 확인합니다.
- Secret 값은 values 파일과 Terraform 변수에 기록하지 않고 Kubernetes Secret으로만 관리합니다.
- Kubeconfig와 Kubernetes Secret 원문은 Git 또는 CI log에 출력하지 않습니다.
- cloudwatch-exporter AWS 키는 Git에 넣지 말고 로컬에서 Secret을 생성합니다.
- CloudWatch exporter metric 이름은 실제 배포 후 Prometheus `/graph`에서 확인한 뒤 AWS 리소스 알림을 추가합니다.
- cloudwatch-exporter와 blackbox-exporter도 `role=monitoring` node에 배치합니다.

## 적용 방법

1. `monitoring` namespace에 다음 Secret을 생성합니다.
    - `cloudwatch-exporter-aws-credentials`
    - `alertmanager-slack-webhook` (`#baro-onprem-alerts`)
    - `alertmanager-aws-slack-webhook` (`#baro-aws-alerts`)
    - `alertmanager-service-slack-webhook` (`#baro-service-alert`)
   - key: `access_key`, `secret_key`
   - 예시:
     ```bash
     kubectl -n monitoring create secret generic cloudwatch-exporter-aws-credentials \
       --from-literal=access_key='<AWS_ACCESS_KEY_ID>' \
       --from-literal=secret_key='<AWS_SECRET_ACCESS_KEY>'

      kubectl -n monitoring create secret generic alertmanager-slack-webhook \
        --from-literal=webhook_url='<ONPREM_SLACK_INCOMING_WEBHOOK_URL>'

      kubectl -n monitoring create secret generic alertmanager-aws-slack-webhook \
        --from-literal=webhook_url='<AWS_SLACK_INCOMING_WEBHOOK_URL>'

      kubectl -n monitoring create secret generic alertmanager-service-slack-webhook \
        --from-literal=webhook_url='<SERVICE_SLACK_INCOMING_WEBHOOK_URL>'
     ```
2. `helm-values/blackbox-exporter.yaml`의 `serviceMonitor.targets`에 실제 public/internal health endpoint와 Kafka TCP target을 추가합니다.
3. `terraform/k3s`에서 `terraform fmt -recursive` 후 `terraform init`, `terraform validate`를 실행합니다.
4. 적용 후 Prometheus `/targets`, `/graph`에서 cloudwatch/blackbox metric 수집 여부를 확인합니다.
5. Prometheus `/rules`에서 `baro.dev.aws.*` 알람 룰이 로드되었는지 확인합니다.
6. Grafana에서 `Baro / Baro AWS Observability` 대시보드를 확인합니다.
7. Grafana에서 `Baro / Baro Service Observability` 대시보드를 확인합니다.
8. Alertmanager에서 Slack receiver와 알람 라우팅을 확인합니다.

## 관련 문서

- [Network and VPN](network-vpn.md)
- [Backup and Recovery](backup-recovery.md)
- [AWS Monitoring and Alert Policy](aws-monitoring-alert-policy.md)
- [Service Monitoring and Alert Policy](service-monitoring-alert-policy.md)
- [Terraform and CI/CD](terraform-cicd.md)
- [Operation Guide](operation-guide.md)
