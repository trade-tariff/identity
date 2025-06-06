data "aws_iam_policy_document" "task" {
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:AdminAddUserToGroup",
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminDeleteUser",
      "cognito-idp:AdminGetUser",
      "cognito-idp:AdminInitiateAuth",
      "cognito-idp:AdminListGroupsForUser",
      "cognito-idp:AdminRemoveUserFromGroup",
      "cognito-idp:AdminUpdateUserAttributes",
    ]
    resources = [data.aws_cognito_user_pool.this.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:RespondToAuthChallenge"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "task" {
  name   = "identity-tasks-role-policy"
  policy = data.aws_iam_policy_document.task.json
}

data "aws_iam_policy_document" "exec" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKeyPair",
      "kms:GenerateDataKeyPairWithoutPlainText",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
    ]
    resources = [
      data.aws_kms_key.this.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = [data.aws_secretsmanager_secret.this.arn]
  }
}

resource "aws_iam_policy" "exec" {
  name   = "identity-execs-role-policy"
  policy = data.aws_iam_policy_document.exec.json
}
