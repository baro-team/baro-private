variable "kubeconfig_path" {
  description = "Path to K3s kubeconfig file"
  type        = string
  default     = "~/terraform-temp/k3s-kubeconfig.yaml"
}

# ──────────────────────────────────────
# monitoring (kube-prometheus-stack)
# ──────────────────────────────────────
variable "monitoring_chart_version" {
  description = "kube-prometheus-stack chart version"
  type        = string
  default     = "84.1.2"
}

variable "cloudwatch_exporter_chart_version" {
  description = "prometheus-cloudwatch-exporter chart version"
  type        = string
  default     = "0.28.1"
}

variable "blackbox_exporter_chart_version" {
  description = "prometheus-blackbox-exporter chart version"
  type        = string
  default     = "11.12.0"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "prometheus_external_url" {
  description = "Externally reachable Prometheus base URL used in alert links"
  type        = string
  default     = "http://192.168.203.187:30900"
}

variable "gateway_metrics_scheme" {
  description = "Scheme used by Prometheus to scrape gateway-service actuator metrics"
  type        = string
  default     = "https"
}

variable "gateway_metrics_targets" {
  description = "Gateway-service host[:port] targets for Prometheus /actuator/prometheus scraping. The default uses the dev internal ALB for bootstrap convenience; override with per-task or internal instance targets when accurate counter/rate and per-instance gauge metrics are required."
  type        = list(string)
  default     = ["internal-dev.barocloud.com:443"]
}

variable "control_metrics_scheme" {
  description = "Scheme used by Prometheus to scrape control-service actuator metrics"
  type        = string
  default     = "https"
}

variable "control_metrics_targets" {
  description = "Control-service host[:port] targets for Prometheus /actuator/prometheus scraping. Prefer direct task/service-discovery targets; override per environment if Cloud Map is not reachable from the monitoring cluster."
  type        = list(string)
  default     = ["control-metrics.dev.barocloud.com:443"]
}

variable "dispatch_metrics_scheme" {
  description = "Scheme used by Prometheus to scrape dispatch-service actuator metrics"
  type        = string
  default     = "https"
}

variable "dispatch_metrics_targets" {
  description = "Dispatch-service host[:port] targets for Prometheus /actuator/prometheus scraping. Prefer direct task/service-discovery targets; override per environment if Cloud Map is not reachable from the monitoring cluster."
  type        = list(string)
  default     = ["dispatch-metrics.dev.barocloud.com:443"]
}

variable "ec2_node_exporter_targets" {
  description = "EC2 node-exporter targets for AWS-side hosts reachable from the monitoring cluster through VPN. Labels identify each target role."
  type = list(object({
    target = string
    role   = string
  }))
  default = [
    {
      target = "10.20.10.31:9100"
      role   = "kafka"
    },
    {
      target = "10.20.10.208:9100"
      role   = "mosquitto"
    }
  ]
}

# ──────────────────────────────────────
# airflow
# ──────────────────────────────────────
variable "airflow_chart_version" {
  description = "Apache Airflow chart version"
  type        = string
  default     = "1.21.0"
}

variable "airflow_db_password" {
  description = "Airflow metadata DB password"
  type        = string
  sensitive   = true
}

# ──────────────────────────────────────
# timescaledb
# ──────────────────────────────────────
variable "timescaledb_chart_version" {
  description = "TimescaleDB chart version"
  type        = string
  default     = "0.11.2"
}

variable "timescaledb_password" {
  description = "TimescaleDB postgres password"
  type        = string
  sensitive   = true
}
