source "amazon-ebs" "ubuntu" {
  ami_name      = local.ami_name
  instance_type = "t2.micro"
  region        = var.region

  vpc_filter {
    filters = {
      "tag:Name" : "${local.common_name_prefix}-Asgard-VPC"
    }
  }

  subnet_id = var.subnet_id

  ami_regions     = [] # Important for Disaster Recovery and HA
  skip_create_ami = false
  source_ami      = data.amazon-ami.ubuntu.id
  ssh_username    = "ubuntu"

  tags = {
    Name = "${local.common_name_prefix}-ado-agent-ubuntu-24.04"

  }
}

build {
  name = "ado-build-server"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "file" {
    sources = [
      "scripts/terminate_agent.sh"
    ]
    destination = "/home/ubuntu/"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /home/ubuntu/terminate_agent.sh"
    ]
  }

  provisioner "shell" {
    script = "scripts/get_deps.sh"
  }
}