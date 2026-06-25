resource "helm_release" "monitoring" {
  name             = "monitoring"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.monitoring_chart_version

  values = [
    templatefile("${path.module}/helm-values/prometheus.yaml", {
      prometheus_external_url    = var.prometheus_external_url
      gateway_metrics_scheme     = var.gateway_metrics_scheme
      gateway_metrics_targets    = var.gateway_metrics_targets
      control_metrics_scheme     = var.control_metrics_scheme
      control_metrics_targets    = var.control_metrics_targets
      dispatch_metrics_scheme    = var.dispatch_metrics_scheme
      dispatch_metrics_targets   = var.dispatch_metrics_targets
      ec2_node_exporter_targets  = var.ec2_node_exporter_targets
      kafka_jmx_exporter_targets = var.kafka_jmx_exporter_targets
    }),
    file("${path.module}/helm-values/kafka-load-test-dashboard.yaml")
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

resource "helm_release" "kafka_exporter" {
  name             = "kafka-exporter"
  namespace        = "monitoring"
  create_namespace = false

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-kafka-exporter"
  version    = var.kafka_exporter_chart_version

  values = [
    templatefile("${path.module}/helm-values/kafka-exporter.yaml", {
      kafka_servers = var.kafka_exporter_kafka_servers
      topic_filter  = var.kafka_exporter_topic_filter
      group_filter  = var.kafka_exporter_group_filter
    })
  ]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600

  depends_on = [helm_release.monitoring]
}
