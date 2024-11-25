# Lambda for Scaling based on ADO queue length
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.poll_ado_queue.arn
}

resource "aws_lambda_function" "scale_function" {
  function_name = local.ado_lambda.name
  handler       = "bootstrap"
  runtime       = "provided.al2"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "scripts/scale_function/scaleFunction.zip"

  environment {
    variables = {
      TEST_ASG_NAME       = module.asg["test"].autoscaling_group_name
      TEST_POOL_ID        = var.asg_configs.test.pool_id
      DEPLOY_ASG_NAME     = module.asg["deploy"].autoscaling_group_name
      DEPLOY_POOL_ID      = var.asg_configs.deploy.pool_id
      BUILD_ASG_NAME      = module.asg["build"].autoscaling_group_name
      BUILD_POOL_ID       = var.asg_configs.build.pool_id
      ADO_PROJECT         = var.ado_project
      ADO_ORG             = var.ado_org
      ADO_LAMBDA_PAT_NAME = local.ado_lambda.pat
    }
  }
}

// Lambda to invoke SSM Command
# Archive a file to be used with Lambda using consistent file mode
data "archive_file" "ssm_handler_zip" {
  type             = "zip"
  source_file      = "scripts/safety_termination/ssm_handler.py"
  output_file_mode = "0666"
  output_path      = "scripts/safety_termination/ssm_handler.zip"
}

resource "aws_lambda_function" "ssm_handler" {
  filename      = "scripts/safety_termination/ssm_handler.zip"
  function_name = "${local.common_name_prefix}-SSM-Handler"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "ssm_handler.lambda_handler"
  runtime       = "python3.12"

  environment {
    variables = {
      SSM_DOCUMENT_NAME = aws_ssm_document.terminate_agent.name
    }
  }
}

resource "aws_lambda_permission" "sns_invoke_lambda" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ssm_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.terminate_topic.arn
}