locals {
  common_name_prefix = "${var.region_prefix}-${var.environment}"
  ado_name_prefix    = "${local.common_name_prefix}-ADO-Agents"

  asg_name = {
    for key, config in var.asg_configs :
    key => "${local.common_name_prefix}-${key}-ASG"
  }

  sg_name                    = "${local.ado_name_prefix}-SG"
  cloudwatch_event_rule_name = "${local.common_name_prefix}-Scaling-Lambda"

  ado_agent = {
    iam_role_name = var.environment != "Prod" ? "ADOAgentRole${var.environment}" : "ADOAgentRole"
    pat           = "${local.ado_name_prefix}-PAT"
    prefix = {
      for key, config in var.asg_configs :
      key => "${local.common_name_prefix}-ADO-${key}-Agents"
    }
  }

  ado_lambda = {
    iam_role_name = var.environment != "Prod" ? "ADOLambdaRole${var.environment}" : "ADOLambdaRole"
    name          = "${local.ado_name_prefix}-Scaling-Lambda"
    pat           = "${local.ado_name_prefix}-Lambda-PAT"
  }

  eventbridge = {
    iam_role_name = var.environment != "Prod" ? "ADOEventBridgeRole${var.environment}" : "ADOEventBridgeRole"
  }


  key_name = "${local.ado_name_prefix}-key"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Application_ID = "ADO Agents"
    Environment    = var.environment
    Version        = 1
    Compliance     = "sox"
    ADO_Project    = "TBC Projects"
    Repository     = "AWSInfrastructure"
  }
}