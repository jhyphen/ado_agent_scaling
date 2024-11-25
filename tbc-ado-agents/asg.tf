module "asg" {
  source = "git::https://triumphbcap.visualstudio.com/Terraform%20Modules/_git/terraform-aws-autoscaling?ref=v8.0.0"

  for_each = var.asg_configs

  name = local.asg_name[each.key]

  min_size                  = each.value.min_size
  max_size                  = each.value.max_size
  desired_capacity          = each.value.desired_capacity
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = data.aws_subnets.private_subnet.ids

  create_iam_instance_profile = false
  iam_instance_profile_arn    = aws_iam_instance_profile.ado_agent.arn

  image_id = data.aws_ami.ado_agent.id

  instance_name = local.ado_agent.prefix[each.key]
  instance_type = each.value.instance_type

  key_name = local.key_name

  launch_template_name = local.ado_agent.prefix[each.key]

  security_groups = [aws_security_group.allow_ssh_from_vpn.id]

  initial_lifecycle_hooks = [
    {
      name                    = "ado-termination-hook"
      default_result          = "CONTINUE"
      heartbeat_timeout       = 1800
      lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_target_arn = aws_sns_topic.terminate_topic.arn
      role_arn                = aws_iam_role.lifecycle_hook_role.arn
    }
  ]

  # Autoscaling Schedule
  schedules = {
    off_hours_downtime = {
      min_size         = 0
      max_size         = 0
      desired_capacity = 0
      recurrence       = "0 3 * * *" # 3:00 CST Daily
      time_zone        = "America/Chicago"
    }

    business_hours = {
      min_size         = each.value.min_size
      max_size         = each.value.max_size
      desired_capacity = each.value.desired_capacity
      recurrence       = "15 3 * * *" # 3:15 CST Daily
      time_zone        = "America/Chicago"
    }
  }

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/sda1"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = var.volume_size
        volume_type           = var.volume_type
      }
    }
  ]

  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = [aws_security_group.allow_ssh_from_vpn.id]
    }
  ]

  user_data = base64encode(templatefile("${path.module}/scripts/install_and_start_agents.sh",
    {
      ado_agent_pool = each.value.ado_agent_pool
      pat            = local.ado_agent.pat
      pool_id        = each.value.pool_id
      org            = var.ado_org
  }))

  tags = merge(local.common_tags, {
    AgentPool = each.key
    PoolId    = each.value.pool_id
  })
}
