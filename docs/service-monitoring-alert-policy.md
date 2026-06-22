# Service Monitoring and Alert Policy

dev 환경의 애플리케이션 서비스 지표와 CircuitBreaker 상태 알림 기준을 정의한다.

## 기본 방향

- AWS 인프라 알림은 `#baro-aws-alerts`, 온프렘/k3s 기본 알림은 `#baro-onprem-alerts`, 애플리케이션 서비스 알림은 `#baro-service-alert`로 분리한다.
- 서비스 알림은 `source="service"` 라벨을 사용한다.
- 서비스 알림은 blackbox 생존 감시, HTTP/JVM whitebox 지표, telemetry pipeline, fleet/dispatch 도메인 지표를 함께 본다.

## Slack 알림

| 구분 | 조건 | Slack 채널 | Webhook Secret |
|---|---|---|---|
| 서비스 알림 | `source="service"` | `#baro-service-alert` | `alertmanager-service-slack-webhook` |

Secret 생성 예시:

```bash
kubectl -n monitoring create secret generic alertmanager-service-slack-webhook \
  --from-literal=webhook_url='<SERVICE_SLACK_INCOMING_WEBHOOK_URL>'
```

## Service metrics scrape

Prometheus는 서비스별 actuator Prometheus endpoint를 scrape한다.

기본 설정:

```hcl
gateway_metrics_scheme = "https"
gateway_metrics_targets = ["internal-dev.barocloud.com:443"]
control_metrics_scheme = "https"
control_metrics_targets = ["control-metrics.dev.barocloud.com:443"]
dispatch_metrics_scheme = "https"
dispatch_metrics_targets = ["dispatch-metrics.dev.barocloud.com:443"]
```

기본값은 dev bootstrap 편의를 위한 internal ALB의 고정 도메인이다. Terraform은 internal ALB에서 gateway는 `internal-dev.barocloud.com`, control/dispatch는 각각 `control-metrics.dev.barocloud.com`, `dispatch-metrics.dev.barocloud.com` host 기반으로 actuator endpoint를 target group에 라우팅한다.

운영 환경 및 정확한 메트릭 분석이 필요한 경우, `gateway_metrics_targets`에 로드 밸런서 도메인이 아닌 Gateway task 또는 내부 인스턴스의 직접 접근 가능한 `host:port` 목록을 설정해야 한다. 로드 밸런서를 scrape하면 매 요청마다 다른 task로 라우팅될 수 있으므로 다음 문제가 발생한다.

1. 카운터 메트릭 왜곡: 각 task의 카운터 값이 달라 `rate()`나 `increase()` 계산 시 카운터 리셋으로 오인되어 메트릭이 왜곡될 수 있다.
2. 상태 메트릭 플래핑: CircuitBreaker 상태(`resilience4j_circuitbreaker_state`) 같은 Gauge 메트릭이 매 scrape마다 달라져 오경보가 발생할 수 있다.

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

각 앱에서는 `/actuator/prometheus`가 노출되어 있어야 한다. 예를 들어 ECS 환경변수에는 다음이 필요하다.

```text
GATEWAY_MANAGEMENT_ENDPOINTS=health,info,metrics,prometheus
CONTROL_MANAGEMENT_ENDPOINTS=health,info,metrics,prometheus
DISPATCH_MANAGEMENT_ENDPOINTS=health,info,metrics,prometheus
```

## Blackbox probe

Blackbox exporter는 외부 관점의 생존 여부를 확인한다.

대상:

- `https://dev.barocloud.com/`
- `https://internal-dev.barocloud.com/actuator/prometheus`
- `https://control-metrics.dev.barocloud.com/actuator/health`
- `https://dispatch-metrics.dev.barocloud.com/actuator/health`
- `kafka.baro.internal:9092`

알림 기준:

| 알람 | Prometheus 지표 | 기준 | 등급 |
|---|---|---:|---|
| Blackbox probe failed | `probe_success` | 3분 이상 0, `source="service"`로 서비스 알림 채널 라우팅 | critical |

## Telemetry / Fleet / Dispatch 도메인 알람 기준

| 알람 | Prometheus 지표 | 기준 | 등급 |
|---|---|---:|---|
| Control metrics down | `up{job="baro-control-service"}` | 3분 이상 0 | critical |
| Dispatch metrics down | `up{job="baro-dispatch-service"}` | 3분 이상 0 | critical |
| Kafka publish failure | `baro_control_telemetry_kafka_publish_failed_total` | 5분 증가량 > 0 | warning |
| SSE send failures high | `baro_control_sse_send_failures_total` | 5분 증가량 > 20 | warning |
| Vehicle idle ratio high | `sum(baro_dispatch_vehicle_status_current{status="idle"}) / sum(baro_dispatch_vehicle_status_current)` | 5분 이상 90% 초과 | warning |
| Active fleet low | `(sum(baro_dispatch_vehicle_status_current{status=~"driving|moving_to_pickup|relocating"}) or vector(0))` | 전체 100대 이상인데 active 10대 미만 | warning |
| Idle GEO saves spike | `baro_dispatch_idle_geo_saves_total` | 5분 증가량 > 500 | warning |
| Idle GEO pool empty | `baro_dispatch_idle_geo_count` | 5분 이상 0 | warning |
| Candidate not found high | `baro_dispatch_idle_geo_candidate_not_found_total` | 5분 증가량 > 20 | warning |

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
