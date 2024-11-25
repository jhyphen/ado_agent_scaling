data "aws_availability_zones" "available" {}

data "aws_ami" "ado_agent" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ado-agent-ubuntu-24.04-*"]
  }
}

data "aws_vpc" "vpc" {
  tags = {
    Name = "${local.common_name_prefix}-Asgard-VPC"
  }
}

data "aws_subnets" "private_subnet" {
  filter {
    name   = "tag:Name"
    values = ["${local.common_name_prefix}-Asgard-VPC-PrivateSubnet"]
  }
}

data "aws_secretsmanager_secret" "ado_pat" {
  name = local.ado_agent.pat
}

data "aws_secretsmanager_secret" "ado_lambda_pat" {
  name = local.ado_lambda.pat
}

data "aws_iam_policy" "ssm_instance_policy" {
  name = "AmazonSSMManagedInstanceCore"
}