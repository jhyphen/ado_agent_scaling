variable "region_prefix" {
  description = "The abbreviation of the region. i.e. VA, OH, etc."
}

variable "region" {
  description = "The region to create the resources in"
}

variable "environment" {
    description = "The working environment (i.e. Dev, QA, UAT, Prod)"
}

variable "subnet_id" {
    description = "The subnet that Packer will use to spin up a temporary EC2 instance for image creation"
}