resource "aws_security_group" "allow_ssh_from_vpn" {
  name        = local.sg_name
  description = "Allows SSH from Dallas VPN"
  vpc_id      = data.aws_vpc.vpc.id

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_vpn" {
  security_group_id = aws_security_group.allow_ssh_from_vpn.id
  cidr_ipv4         = "10.155.16.0/23"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_ipv4" {
  security_group_id = aws_security_group.allow_ssh_from_vpn.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}



