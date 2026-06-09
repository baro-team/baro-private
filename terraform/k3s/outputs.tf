output "monitoring_status" {
  description = "monitoring release status"
  value       = helm_release.monitoring.status
}

output "airflow_status" {
  description = "airflow release status"
  value       = helm_release.airflow.status
}

output "timescaledb_status" {
  description = "timescaledb release status"
  value       = helm_release.timescaledb.status
}
