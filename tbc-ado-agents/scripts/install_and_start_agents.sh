#!/bin/bash
set -e
runuser ubuntu bash -c '
TOKEN=$(aws secretsmanager get-secret-value --secret-id ${pat} --region us-east-1  --query SecretString --output text | jq -r '.ADO_AGENT_TOKEN')
DIRS=("agent")

for DIR in "$${DIRS[@]}"; do 
        # Configure Agents
        DIR_PATH="/home/ubuntu/$${DIR}/"
        echo "Running $DIR/config.sh"
        "$DIR_PATH/config.sh" --unattended --url https://dev.azure.com/triumphbcap --auth pat --token $${TOKEN} --pool ${ado_agent_pool} --agent $(hostname)-$DIR --replace --acceptTeeEula
        # Install and Start ADO Agent
        cd $${DIR_PATH}
        echo "Running $${DIR_PATH}/svc.sh install and start"
        sudo ./svc.sh install
        if [ $? -ne 0 ]; then
                echo "Error installing ADO Agent service"
                exit 21
        fi
        sudo ./svc.sh start
done

echo "ADO AGENTS CONFIGURED"

# Set environment variables
'
# This is necessary for scripts baked into AMI
echo export ADO_AGENT_TOKEN=${pat} >> /etc/profile.d/myenv.sh
echo export POOL_ID=${pool_id} >> /etc/profile.d/myenv.sh
echo export ORG=${org} >> /etc/profile.d/myenv.sh

# Start SSM Agent
snap start amazon-ssm-agent

