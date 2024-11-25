variable "region_prefix" {
  description = "The abbreviation of the region. i.e. VA, OH, etc."
}

variable "region" {
  description = "The region to create the resources in"
}

variable "environment" {

}

variable "volume_type" {
  description = "The type of EBS volume you wish to configure. (i.e. gp2, gp3)"
  default     = "gp2"
}

variable "instance_type" {
  description = "The type of instance."
  default     = "t3a.small"
}

variable "volume_size" {
  description = "The size of EBS storage. (i.e. 200 = 200GB)"
  default     = 20
}

variable "asg_configs" {
  type = map(object({
    instance_type    = string
    ado_agent_pool   = string
    min_size         = number
    max_size         = number
    desired_capacity = number
    pool_id          = number
    queue_id         = number
  }))
}

variable "ado_project" {
  description = "The ADO Project Name i.e. TBC Project"
  default     = "TBC%20Projects"
}

variable "ado_org" {
  description = "The name of the organization i.e. triumphbcap"
  default     = "triumphbcap"
}
