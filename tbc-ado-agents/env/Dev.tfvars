environment = "Dev"
region_prefix = "VA"
region = "us-east-1"

volume_size = 500

asg_configs = {
    "build" = {
        instance_type = "t3a.2xlarge"
        min_size = 0
        max_size = 1
        desired_capacity = 1
        ado_agent_pool = "build-agent-ubuntu-pool"
        pool_id = "74"
        queue_id = "560"

    },
    "deploy" = {
        instance_type = "t3a.large"
        min_size = 0
        max_size = 1
        desired_capacity = 1
        ado_agent_pool = "deploy-agent-ubuntu-pool"
        pool_id = "75"
        queue_id = "561"
    },
    "test" = {
        instance_type = "t3a.xlarge"
        min_size = 0
        max_size = 1
        desired_capacity = 1
        ado_agent_pool = "test-agent-ubuntu-pool"
        pool_id = "76"
        queue_id = "562"

    }
}
