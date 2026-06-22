# AWS Monitoring and Alert Policy

dev 환경에서 CloudWatch exporter로 수집하는 AWS 지표와 알람 기준을 정의한다.

## 기본 방향

- 이번 범위는 AWS 리소스만 대상으로 한다.
- 대상 리소스는 ALB, ECS, RDS, ElastiCache, EC2다.
- 장애로 이어질 가능성이 높은 지표는 `critical`, 용량 증설이나 튜닝 검토가 필요한 지표는 `warning`으로 분리한다.
- 순간 스파이크를 줄이기 위해 일정 시간 지속되는 경우에만 알람을 발생시킨다.
- 알림 발송 채널은 Slack Webhook, 이메일, SNS 등 비밀값이 필요하므로 Git에 저장하지 않고 Kubernetes Secret 또는 외부 Secret으로 주입한다.

## 관찰 대상과 알람 기준

| AWS 영역 | CloudWatch 지표 | Prometheus 지표 | 알람 기준 | 등급 | 의미 |
|---|---|---|---:|---|---|
| ALB | `HTTPCode_Target_5XX_Count` | `aws_applicationelb_httpcode_target_5_xx_count_sum` | 10분 이상 10건 이상 | critical | downstream 서비스 오류 또는 라우팅 문제 |
| ALB | `TargetResponseTime` | `aws_applicationelb_target_response_time_average` | 10분 이상 평균 2초 초과 | warning | Gateway 뒤 서비스 응답 지연 |
| ECS | `CPUUtilization` | `aws_ecs_cpuutilization_average` | 10분 이상 80% 초과 | warning | CPU 병목 또는 scale-out 필요 |
| ECS | `MemoryUtilization` | `aws_ecs_memory_utilization_average` | 10분 이상 85% 초과 | warning | 메모리 부족 또는 누수 가능성 |
| RDS | `CPUUtilization` | `aws_rds_cpuutilization_average` | 15분 이상 80% 초과 | warning | DB 부하 증가 |
| RDS | `FreeStorageSpace` | `aws_rds_free_storage_space_average` | 15분 이상 10GiB 미만 | critical | 스토리지 고갈 위험 |
| RDS | `DatabaseConnections` | `aws_rds_database_connections_average` | 15분 이상 80개 초과 | warning | connection pool/쿼리 병목 가능성 |
| ElastiCache | `CPUUtilization` | `aws_elasticache_cpuutilization_average` | 10분 이상 80% 초과 | warning | Redis CPU 병목 |
| ElastiCache | `DatabaseMemoryUsagePercentage` | `aws_elasticache_database_memory_usage_percentage_average` | 10분 이상 85% 초과 | warning | Redis 메모리 부족 위험 |
| ElastiCache | `Evictions` | `aws_elasticache_evictions_sum` | 5분 이상 0 초과 | critical | 캐시 메모리 부족으로 데이터 축출 발생 |
| EC2 | `StatusCheckFailed_Instance`, `StatusCheckFailed_System` | `aws_ec2_status_check_failed_instance_maximum`, `aws_ec2_status_check_failed_system_maximum` | 5분 이상 실패 | critical | 인스턴스 또는 호스트 장애 |
| EC2 | `CPUUtilization` | `aws_ec2_cpuutilization_average` | 15분 이상 85% 초과 | warning | 인스턴스 부하 증가 |

## Slack 알림

Alertmanager는 알람의 `source` 라벨로 Slack 채널을 분리한다.

| 구분 | 조건 | Slack 채널 | Webhook Secret |
|---|---|---|---|
| AWS 알람 | `source="aws"` | `#baro-aws-alerts` | `alertmanager-aws-slack-webhook` |
| 온프렘/k3s 기본 알람 | `source` 없음 또는 AWS 외 알람 | `#baro-onprem-alerts` | `alertmanager-slack-webhook` |

AWS 알람 룰에는 모두 아래 공통 라벨을 추가한다.

```yaml
source: aws
```

| 등급 | Slack title | 반복 주기 |
|---|---|---:|
| AWS critical | `[AWS][CRITICAL] 알람명` | 1시간 |
| AWS warning | `[AWS][WARNING] 알람명` | 4시간 |
| 온프렘 critical | `[ONPREM][CRITICAL] 알람명` | 1시간 |
| 온프렘 warning | `[ONPREM][WARNING] 알람명` | 4시간 |

Slack 본문에는 오래 전에 발생한 알람이 지금 새로 발생한 것처럼 보이지 않도록 Alertmanager가 전달한 시각 정보를 함께 표시한다.

- 상태: `firing` 또는 `resolved`
- 발생시각: `StartsAt` UTC 시각
- 설명: 알람 annotation description

Slack 알림 제목 링크는 Prometheus가 생성한 `GeneratorURL`을 사용한다. 이 URL이 클러스터 내부 주소가 아니라 실제 접근 가능한 주소로 표시되도록 Prometheus `externalUrl`을 설정한다. `/query`는 Prometheus 화면 경로이므로 `externalUrl`에는 포함하지 않는다.

`externalUrl`은 Terraform 변수 `prometheus_external_url`로 주입한다. 기본값은 현재 dev 네트워크에서 접근 가능한 Prometheus NodePort 주소다.

```yaml
prometheus:
  prometheusSpec:
    externalUrl: http://192.168.203.187:30900
```

환경별로 주소가 달라지면 다음처럼 Terraform 변수로 덮어쓴다.

```bash
TF_VAR_prometheus_external_url='http://<PROMETHEUS_HOST>:30900' terraform apply
```

AWS 알람은 `source="aws"` 부모 라우트 아래에서 severity별 receiver로 분기한다. 따라서 AWS 알람에 새 severity가 추가되더라도 온프렘 채널로 새지 않고 AWS warning receiver로 전달된다.

Slack Webhook URL은 Git에 저장하지 않고 Kubernetes Secret으로 주입한다.

```bash
# 기존 온프렘/k3s 기본 알람 채널: #baro-onprem-alerts
kubectl -n monitoring create secret generic alertmanager-slack-webhook \
  --from-literal=webhook_url='<ONPREM_SLACK_INCOMING_WEBHOOK_URL>'

# AWS 알람 채널: #baro-aws-alerts
kubectl -n monitoring create secret generic alertmanager-aws-slack-webhook \
  --from-literal=webhook_url='<AWS_SLACK_INCOMING_WEBHOOK_URL>'
```

`Watchdog`, `CPUThrottlingHigh`, `NodeFilesystemSpaceFillingUp` 같은 kube-prometheus-stack 기본 알람은 AWS 알람이 아니므로 `#baro-onprem-alerts`로 전달한다. K3s에서 표준 scrape target으로 노출되지 않는 control-plane component 알림은 오탐 방지를 위해 비활성화한다.

## Grafana 대시보드

`Baro AWS Observability` 대시보드를 Grafana `Baro` 폴더에 provision한다.

포함 패널:

- ALB Target 5xx
- ALB Target Response Time
- ECS CPU Utilization
- ECS Memory Utilization
- RDS CPU Utilization
- RDS Free Storage
- RDS Connections
- ElastiCache CPU Utilization
- ElastiCache Memory Usage
- ElastiCache Evictions
- EC2 CPU Utilization
- EC2 Status Check Failed

## 현재 반영 위치

- Prometheus alert rule: `terraform/k3s/helm-values/prometheus.yaml`
- Alertmanager Slack receiver: `terraform/k3s/helm-values/prometheus.yaml`
- Grafana dashboard: `terraform/k3s/helm-values/prometheus.yaml`
- CloudWatch exporter 수집 지표: `terraform/k3s/helm-values/cloudwatch-exporter.yaml`

## 적용 후 확인 절차

1. Terraform 적용 후 Prometheus UI에서 `/targets`를 확인한다.
2. Prometheus `/rules`에서 `baro.dev.aws.*` rule group이 로드되었는지 확인한다.
3. Prometheus `/graph`에서 CloudWatch exporter metric 이름을 확인한다.
   - 예: `aws_applicationelb_httpcode_target_5_xx_count_sum`
   - 예: `aws_ecs_cpuutilization_average`
   - 예: `aws_rds_free_storage_space_average`
4. 실제 metric 이름이 exporter 변환 결과와 다르면 alert rule의 metric name만 수정한다.
5. Grafana에서 `Baro / Baro AWS Observability` 대시보드가 생성되었는지 확인한다.
6. Alertmanager UI에서 알람 라우팅과 Slack receiver를 확인한다.

## 추가로 결정할 것

- critical과 warning을 같은 채널로 보낼지 분리할지 결정
- 야간/휴일 알림 정책 결정
- 알람 반복 주기와 silence 운영 방식 결정
