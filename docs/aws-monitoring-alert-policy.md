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

Alertmanager는 `critical`, `warning` 알람을 Slack으로 발송한다.

| 등급 | Slack title | 반복 주기 |
|---|---|---:|
| critical | `[CRITICAL] 알람명` | 1시간 |
| warning | `[WARNING] 알람명` | 4시간 |

Slack Webhook URL은 Git에 저장하지 않고 Kubernetes Secret으로 주입한다.

```bash
kubectl -n monitoring create secret generic alertmanager-slack-webhook \
  --from-literal=webhook_url='<SLACK_INCOMING_WEBHOOK_URL>'
```

현재 Alertmanager 설정의 기본 채널명은 `#baro-alerts`다. Slack Incoming Webhook이 특정 채널에 고정되어 있으면 Webhook 설정을 우선 따른다.

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
