data "aws_vpc" "vpc" {
  tags = { Name = "trade-tariff-${var.environment}-vpc" }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Name = "*private*"
  }
}

data "aws_lb_target_group" "this" {
  name = "identity"
}

data "aws_security_group" "this" {
  name = "trade-tariff-ecs-security-group-${var.environment}"
}

data "aws_kms_key" "this" {
  key_id = "alias/secretsmanager-key"
}

data "aws_secretsmanager_secret" "this" {
  name = "identity-configuration"
}

data "aws_secretsmanager_secret_version" "this" {
  secret_id = data.aws_secretsmanager_secret.this.id
}

data "aws_secretsmanager_secret" "ecs_tls_certificate" {
  name = "ecs-tls-certificate"
}

data "aws_secretsmanager_secret_version" "ecs_tls_certificate" {
  secret_id = data.aws_secretsmanager_secret.ecs_tls_certificate.id
}

data "aws_cognito_user_pool" "this" {
  user_pool_id = local.secret_map["COGNITO_USER_POOL_ID"]
}
