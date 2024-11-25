data "amazon-ami" "ubuntu" {
  region = "us-east-1"
  filters = {
    virtualization-type = "hvm"
    name                = "ubuntu/images/*ubuntu-noble-24.04-amd64-server-*"
    root-device-type    = "ebs"
  }
  owners      = ["099720109477"]
  most_recent = true
}