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

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
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
