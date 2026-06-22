# Terraform and CI/CD

## 문서 목적

이 문서는 OpenStack 및 K3s Terraform 구성, local backend state와 GitHub Actions workflow를 설명합니다.

## Terraform 구성

| 디렉터리 | 관리 대상 | Provider |
|---|---|---|
| `terraform/openstack` | Network, router, port, flavor, VM, volume, security group | OpenStack |
| `terraform/k3s` | Monitoring, TimescaleDB, Airflow Helm release | Helm |

두 구성은 기존 운영 리소스를 import한 state를 사용합니다. 변경 전에는 실제 리소스와 plan이 일치하는지 확인해야 합니다.

## Local Backend

| 대상 | State 경로 |
|---|---|
| OpenStack | `/home/baro/terraform-state/openstack/terraform.tfstate` |
| K3s | `/home/baro/terraform-state/k3s/terraform.tfstate` |

Local backend를 사용하므로 self-hosted runner와 수동 작업은 같은 state 경로를 참조합니다.

- State 파일은 Git에 commit하지 않습니다.
- State는 민감정보를 포함할 수 있습니다.
- State backup은 MinIO에 별도로 보관합니다.
- 동시에 여러 apply를 실행하지 않습니다.

## Sensitive Variable

| Variable | 전달 방식 |
|---|---|
| OpenStack password | `TF_VAR_password` |
| Grafana admin password | `TF_VAR_grafana_admin_password` |
| Prometheus external URL | `TF_VAR_prometheus_external_url` |
| Gateway metrics scheme | `TF_VAR_gateway_metrics_scheme` |
| Gateway metrics target | `TF_VAR_gateway_metrics_target` |
| Airflow DB password | `TF_VAR_airflow_db_password` |
| TimescaleDB password | `TF_VAR_timescaledb_password` |
| K3s kubeconfig path | `TF_VAR_kubeconfig_path` |

Password는 Terraform code와 Helm values에 직접 기록하지 않고 GitHub Actions Secrets 또는 안전한 환경 변수로 전달합니다.

## 수동 검증

```bash
cd terraform/<openstack-or-k3s>
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

다음 변경이 plan에 나타나면 apply 전에 원인을 확인합니다.

- VM, volume, network 또는 subnet 교체
- Fixed IP 변경
- Router 또는 security group 대규모 변경
- Helm release 삭제 후 재설치
- TimescaleDB NodePort 또는 PVC 영향

## GitHub Actions 흐름

```text
Path filter
  -> OpenStack 또는 K3s job 선택
  -> terraform fmt -check
  -> terraform init
  -> terraform validate
  -> terraform plan
  -> main push에서 terraform apply
```

`detect-changes` job은 GitHub-hosted runner에서 실행됩니다. Terraform job은 `self-hosted`, `linux`, `x64`, `openstack` label을 가진 runner에서 실행됩니다.

K3s job은 OpenStack job이 성공하거나 skip된 후 실행됩니다.

## Trigger와 보안

현재 workflow는 다음 event를 사용합니다.

- `main` branch push
- `main` 대상 pull request

교육용 프로젝트에서 PR 단계의 Terraform 검증이 필요해 `pull_request` trigger를 유지합니다. 외부 기여자의 workflow는 팀원 승인이 있어야 실행되도록 GitHub 정책을 설정했으며, 실제 apply는 `main` push에서만 실행됩니다.

Self-hosted runner가 운영 인프라에 접근할 수 있으므로 PR과 workflow 변경은 실행 전 내용을 검토합니다.

## Concurrency

Workflow는 `terraform-production` concurrency group과 `cancel-in-progress: false`를 사용합니다. 기존 실행을 취소하지 않고 apply 충돌 가능성을 줄이기 위한 설정입니다.

Terraform 명령에도 state lock timeout이 적용되지만, local backend를 사용하므로 수동 apply와 workflow apply를 동시에 실행하지 않아야 합니다.

## 변경 절차

1. 코드 수정
2. 수동 `fmt`, `validate`, `plan`
3. Plan의 create, replace, destroy 검토
4. Commit 및 push
5. GitHub Actions 결과 확인
6. 실제 인프라와 서비스 상태 확인

## 관련 문서

- [OpenStack Private Cloud](openstack-private-cloud.md)
- [K3s Cluster](k3s-cluster.md)
- [Backup and Recovery](backup-recovery.md)
- [Operation Guide](operation-guide.md)
