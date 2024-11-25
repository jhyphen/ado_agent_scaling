resource "aws_sns_topic_subscription" "sns_lambda_subscription" {
  topic_arn = aws_sns_topic.terminate_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ssm_handler.arn
}

resource "aws_sns_topic" "terminate_topic" {
  name = "terminate-asg-lifecycle-topic"
}

resource "aws_sns_topic_policy" "sns_autoscaling_policy" {
  arn = aws_sns_topic.terminate_topic.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "autoscaling.amazonaws.com"
        },
        Action   = "sns:Publish",
        Resource = aws_sns_topic.terminate_topic.arn
      }
    ]
  })
}

