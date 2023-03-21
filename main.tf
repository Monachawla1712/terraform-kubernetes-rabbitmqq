resource "random_password" "rabbitmq_password" {
  length  = 20
  special = false
}

resource "random_password" "erlangcookie_password" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "rabbitmq_password" {
  name                    = format("%s/%s/%s", var.rabbitmq_config.environment, var.rabbitmq_config.name, "rabbitmq")
  recovery_window_in_days = var.recovery_window_aws_secret
}

resource "aws_secretsmanager_secret_version" "rabbitmq_password" {
  secret_id     = aws_secretsmanager_secret.rabbitmq_password.id
  secret_string = <<EOF
   {
    "username": "${var.username}",
    "password": "${random_password.rabbitmq_password.result}"
   }
EOF
}

resource "kubernetes_namespace" "rabbitmq" {
  metadata {
    annotations = {}

    name = var.namespace
  }
}

resource "helm_release" "rabbitmq" {
  depends_on = [kubernetes_namespace.rabbitmq]
  name       = "rabbitmq"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "rabbitmq"
  namespace  = var.namespace
  version    = var.chart_version
  timeout    = 600

  values = [
    templatefile("${path.module}/helm/values/values.yaml", {
      rabbitmq_username         = var.username,
      rabbitmq_password         = random_password.rabbitmq_password.result,
      erlangcookie_password     = random_password.erlangcookie_password.result,
      replicacount              = var.rabbitmq_config.replica_count,
      rabbitmq_volume_size      = var.rabbitmq_config.volume_size,
      hostname                  = var.rabbitmq_config.hostname,
      rabbitmq_exporter_enabled = var.rabbitmq_exporter_enabled,
      storage_class_name        = var.rabbitmq_config.storage_class_name
    }),
    var.rabbitmq_config.values_yaml
  ]
}