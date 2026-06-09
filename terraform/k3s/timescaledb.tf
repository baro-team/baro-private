resource "helm_release" "timescaledb" {
  name             = "timescaledb"
  namespace        = "database"
  create_namespace = true

  repository = "oci://registry-1.docker.io/cloudpirates"
  chart      = "timescaledb"
  version    = var.timescaledb_chart_version

  values = [file("${path.module}/helm-values/timescaledb.yaml")]

  set_sensitive {
    name  = "auth.postgresPassword"
    value = var.timescaledb_password
  }

}
