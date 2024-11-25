# ADO Agent IAM Role section
resource "aws_iam_role" "ado_agent_role" {
  name               = local.ado_agent.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.ado_agent_assume_role_policy.json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ado_agent" {
  name   = "ADOAgentPolicy"
  role   = aws_iam_role.ado_agent_role.id
  policy = data.aws_iam_policy_document.allow_ecr_and_secrets_manager.json
}

resource "aws_iam_role_policy_attachment" "ado_agent_ssm" {
  role       = aws_iam_role.ado_agent_role.name
  policy_arn = data.aws_iam_policy.ssm_instance_policy.arn
}

data "aws_iam_policy_document" "ado_agent_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "allow_ecr_and_secrets_manager" {
  statement {
    sid = "ECR"

    actions = [
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeRegistry",
      "ecr:DescribeRepositories",
      "ecr:CreateRepository",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:TagResource",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:CompleteLayerUpload"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid = "PAT"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      "${data.aws_secretsmanager_secret.ado_pat.arn}"
    ]
  }
}

resource "aws_iam_instance_profile" "ado_agent" {
  name = local.ado_name_prefix
  role = aws_iam_role.ado_agent_role.name
}

# Lambda IAM Role section
resource "aws_iam_role" "lambda_exec_role" {
  name = local.ado_lambda.iam_role_name

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "ADOLambdaPolicy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid = "SecretsManagerAccess"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = [
      "${data.aws_secretsmanager_secret.ado_lambda_pat.arn}"
    ]
  }

  statement {
    sid = "ASGScalingAccess"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:UpdateAutoScalingGroup"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid = "CloudWatchLogging"
    actions = [
      "logs:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid = "SSMAccess"
    actions = [
      "ssm:SendCommand",
      "ssm:ListCommands",
      "ssm:GetCommandInvocation"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid = "DynamoDBAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:DescribeTable"
    ]
    resources = [
      "${aws_dynamodb_table.scaling_lock.arn}"
    ]
  }
}

// Lifecycle Hook role
resource "aws_iam_role" "lifecycle_hook_role" {
  name = "lifecycle-hook-role"

  assume_role_policy = data.aws_iam_policy_document.lifecycle_assume_role_policy.json
}

resource "aws_iam_role_policy" "lifecycle_hook_role_policy" {
  name   = "ADOLifecyclePolicy"
  role   = aws_iam_role.lifecycle_hook_role.id
  policy = data.aws_iam_policy_document.lifecycle_hook_policy.json
}

data "aws_iam_policy_document" "lifecycle_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lifecycle_hook_policy" {
  statement {
    sid = "LifecycleHook"
    actions = [
      "sns:Publish"
    ]

    resources = [
      "${aws_sns_topic.terminate_topic.arn}"
    ]
  }
}