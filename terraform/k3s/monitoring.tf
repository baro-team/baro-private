resource "helm_release" "monitoring" {
  name             = "monitoring"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.monitoring_chart_version

  values = [
    templatefile("${path.module}/helm-values/prometheus.yaml", {
      prometheus_external_url = var.prometheus_external_url
      gateway_metrics_scheme  = var.gateway_metrics_scheme
      gateway_metrics_target  = var.gateway_metrics_target
    })
  ]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

}

resource "helm_release" "cloudwatch_exporter" {
  name             = "cloudwatch-exporter"
  namespace        = "monitoring"
  create_namespace = false

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-cloudwatch-exporter"
  version    = var.cloudwatch_exporter_chart_version

  values = [file("${path.module}/helm-values/cloudwatch-exporter.yaml")]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600

  depends_on = [helm_release.monitoring]
}

resource "helm_release" "blackbox_exporter" {
  name             = "blackbox-exporter"
  namespace        = "monitoring"
  create_namespace = false

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  version    = var.blackbox_exporter_chart_version

  values = [file("${path.module}/helm-values/blackbox-exporter.yaml")]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600

  depends_on = [helm_release.monitoring]
}
