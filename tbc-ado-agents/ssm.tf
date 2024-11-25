resource "aws_ssm_document" "terminate_agent" {
  name            = "terminate-agent"
  document_type   = "Command"
  document_format = "YAML"

  content = <<YAML
schemaVersion: '2.2'
description: "Run termination script"
parameters:
mainSteps:
 - action: "aws:runShellScript"
   name: "RunTerminationScript"
   inputs:
    runCommand:
        - "runuser ubuntu -c \"bash -c 'source /etc/profile.d/myenv.sh; /home/ubuntu/terminate_agent.sh'\""
YAML
}