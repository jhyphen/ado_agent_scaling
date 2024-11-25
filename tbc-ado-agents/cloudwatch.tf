resource "aws_cloudwatch_event_rule" "poll_ado_queue" {
  name                = local.cloudwatch_event_rule_name
  description         = "Poll ADO queue every minute for scaling decisions"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.poll_ado_queue.name
  target_id = "pollAdoQueue"
  arn       = aws_lambda_function.scale_function.arn
}
