locals {
  account_id     = data.aws_caller_identity.current.account_id
  has_autoscaler = var.environment == "development" ? false : true
  secret_value   = try(data.aws_secretsmanager_secret_version.this.secret_string, "{}")
  secret_map     = jsondecode(local.secret_value)
  secret_env_vars = [
    for key, value in local.secret_map : {
      name  = key
      value = value
    }
  ]

  tls_secret = jsondecode(data.aws_secretsmanager_secret_version.ecs_tls_certificate.secret_string)

  ecs_tls_env_vars = [
    {
      name  = "SSL_KEY_PEM"
      value = local.tls_secret.private_key
    },
    {
      name  = "SSL_CERT_PEM"
      value = local.tls_secret.certificate
    },
    {
      name  = "SSL_PORT"
      value = "8443"
    }
  ]

  identity_service_env_vars = concat(local.secret_env_vars, local.ecs_tls_env_vars)
  ecr_repo                  = "382373577178.dkr.ecr.eu-west-2.amazonaws.com/tariff-identity-production"

  # Paths the image must still be able to write to under a read-only root filesystem.
  # WORKDIR is /app, so Rails.root-relative paths resolve there.
  #   /tmp      - general scratch
  #   /app/tmp  - bootsnap, loaded in config/boot.rb; without it the app fails to boot
  #   /app/log  - the New Relic agent's own log file (newrelic.yml sets no log_file)
  writable_paths = ["/tmp", "/app/tmp", "/app/log"]

  # Matches the uid/gid pinned in the Dockerfile. The ecs-service module adds an init
  # container that chowns the writable mounts to this user, because Fargate mounts them
  # root-owned and the app runs as the non-root `tariff`.
  container_user = "1000:1000"
}
