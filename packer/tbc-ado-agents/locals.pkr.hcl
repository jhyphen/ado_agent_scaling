locals {
  common_name_prefix = "${var.region_prefix}-${var.environment}"

  ami_name = "ado-agent-ubuntu-24.04-{{timestamp}}"
}