# ECS job for scheduled tasks
# EventBridge triggers the job with a command override for the specific task.

module "identity-job" {
  source = "git@github.com:trade-tariff/trade-tariff-platform-terraform-modules.git//aws/ecs-service?ref=aws/ecs-service-v1.21.0"

  region = var.region

  service_name              = "identity-job"
  container_definition_kind = "job"
  container_command         = ["/bin/sh", "-c", "bin/null-service"]
  service_count             = 0

  cluster_name              = "trade-tariff-cluster-${var.environment}"
  subnet_ids                = data.aws_subnets.private.ids
  security_groups           = [data.aws_security_group.this.id]
  cloudwatch_log_group_name = "platform-logs-${var.environment}"

  docker_image = local.ecr_repo
  docker_tag   = var.docker_tag
  cpu          = var.cpu
  memory       = var.memory

  task_role_policy_arns      = [aws_iam_policy.task.arn]
  execution_role_policy_arns = [aws_iam_policy.exec.arn]
  service_environment_config = local.secret_env_vars

  enable_ecs_exec = true
  has_autoscaler  = false
  max_capacity    = 1
  min_capacity    = 0
}

data "aws_ecs_task_definition" "identity_job" {
  task_definition = "identity-job-${local.account_id}"
  depends_on      = [module.identity-job]
}

resource "aws_cloudwatch_event_rule" "remove_unverified_users" {
  name                = "identity-remove-unverified-users-${var.environment}"
  description         = "Triggers daily removal of unverified users from Cognito"
  schedule_expression = "cron(0 4 * * ? *)"
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "remove_unverified_users" {
  rule     = aws_cloudwatch_event_rule.remove_unverified_users.name
  arn      = data.aws_ecs_cluster.this.arn
  role_arn = aws_iam_role.eventbridge_ecs.arn

  input = jsonencode({
    containerOverrides = [{
      name    = "identity-job"
      command = ["bundle", "exec", "rake", "cleanup:remove_unverified_users"]
    }]
  })

  ecs_target {
    task_count          = 1
    task_definition_arn = data.aws_ecs_task_definition.identity_job.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = data.aws_subnets.private.ids
      security_groups  = [data.aws_security_group.this.id]
      assign_public_ip = false
    }
  }
}

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_ecs" {
  name               = "identity-eventbridge-ecs-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eventbridge_run_task" {
  role       = aws_iam_role.eventbridge_ecs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

data "aws_iam_policy_document" "eventbridge_pass_role" {
  statement {
    actions = ["iam:PassRole"]
    resources = [
      module.identity-job.task_execution_role_arn,
      module.identity-job.task_role_arn,
    ]
  }
}

resource "aws_iam_policy" "eventbridge_pass_role" {
  name   = "identity-eventbridge-pass-role-${var.environment}"
  policy = data.aws_iam_policy_document.eventbridge_pass_role.json
}

resource "aws_iam_role_policy_attachment" "eventbridge_pass_role" {
  role       = aws_iam_role.eventbridge_ecs.name
  policy_arn = aws_iam_policy.eventbridge_pass_role.arn
}
