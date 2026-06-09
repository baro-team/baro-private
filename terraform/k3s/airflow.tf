resource "helm_release" "airflow" {
  name             = "airflow"
  namespace        = "airflow"
  create_namespace = true

  repository = "https://airflow.apache.org"
  chart      = "airflow"
  version    = var.airflow_chart_version

  values = [file("${path.module}/helm-values/airflow.yaml")]

  set_sensitive {
    name  = "data.metadataConnection.pass"
    value = var.airflow_db_password
  }

  depends_on = [helm_release.timescaledb]

}