# Service Monitoring and Alert Policy

dev 환경의 애플리케이션 서비스 지표와 CircuitBreaker 상태 알림 기준을 정의한다.

## 기본 방향

- AWS 인프라 알림은 `#baro-aws-alerts`, 온프렘/k3s 기본 알림은 `#baro-onprem-alerts`, 애플리케이션 서비스 알림은 `#baro-service-alert`로 분리한다.
- 서비스 알림은 `source="service"` 라벨을 사용한다.
- 현재 우선 대상은 `gateway-service`의 Spring Cloud Gateway / Resilience4j CircuitBreaker 지표다.

## Slack 알림

| 구분 | 조건 | Slack 채널 | Webhook Secret |
|---|---|---|---|
| 서비스 알림 | `source="service"` | `#baro-service-alert` | `alertmanager-service-slack-webhook` |

Secret 생성 예시:

```bash
kubectl -n monitoring create secret generic alertmanager-service-slack-webhook \
  --from-literal=webhook_url='<SERVICE_SLACK_INCOMING_WEBHOOK_URL>'
```

## Gateway metrics scrape

Prometheus는 Gateway의 actuator Prometheus endpoint를 scrape한다.

기본 설정:

```hcl
gateway_metrics_scheme = "https"
gateway_metrics_targets = []
```

`gateway_metrics_targets`에는 Load Balancer 도메인이 아니라 Gateway task 또는 내부 인스턴스의 직접 접근 가능한 `host:port` 목록을 넣는다. Load Balancer를 scrape하면 요청마다 다른 task에 붙을 수 있어 CircuitBreaker instance 라벨이 흔들리고 알람 원인 식별이 어려워질 수 있다.

예시 scrape 대상:

```text
https://10.20.10.10:8080/actuator/prometheus
https://10.20.10.11:8080/actuator/prometheus
```

환경별로 대상이 다르면 Terraform 변수로 덮어쓴다.

```bash
TF_VAR_gateway_metrics_scheme='https' \
TF_VAR_gateway_metrics_targets='["10.20.10.10:8080","10.20.10.11:8080"]' \
terraform apply
```

Gateway 앱에서는 `/actuator/prometheus`가 노출되어 있어야 한다. 예를 들어 gateway-service 환경변수에는 다음이 필요하다.

```text
GATEWAY_MANAGEMENT_ENDPOINTS=health,info,metrics,prometheus
```

## CircuitBreaker 알람 기준

| 알람 | Prometheus 지표 | 기준 | 등급 |
|---|---|---:|---|
| Gateway metrics target down | `up{job="baro-gateway-service"}` | 3분 이상 0 | critical |
| CircuitBreaker open | `resilience4j_circuitbreaker_state{state="open"}` | 1분 이상 1 | critical |
| CircuitBreaker half-open | `resilience4j_circuitbreaker_state{state="half_open"}` | 5분 이상 1 | warning |
| Failure rate high | `resilience4j_circuitbreaker_failure_rate` | 5분 이상 50% 이상 | warning |
| Slow call rate high | `resilience4j_circuitbreaker_slow_call_rate` | 5분 이상 50% 이상 | warning |

## Grafana 대시보드

`Baro Service Observability` 대시보드를 Grafana `Baro` 폴더에 provision한다.

포함 패널:

- Gateway Metrics Target Up
- CircuitBreaker State
- CircuitBreaker Failure Rate
- CircuitBreaker Slow Call Rate
- CircuitBreaker Calls

## 적용 후 확인 절차

1. Prometheus `/targets`에서 `baro-gateway-service` target이 UP인지 확인한다.
   - target은 Gateway task/instance별로 보여야 한다.
2. Prometheus `/graph`에서 다음 지표가 수집되는지 확인한다.
   - `resilience4j_circuitbreaker_state`
   - `resilience4j_circuitbreaker_failure_rate`
   - `resilience4j_circuitbreaker_slow_call_rate`
   - `resilience4j_circuitbreaker_calls_seconds_count`
3. Grafana에서 `Baro / Baro Service Observability` 대시보드를 확인한다.
4. Alertmanager 테스트 알람에 `source="service"` 라벨을 붙여 `#baro-service-alert`로 발송되는지 확인한다.
