#!/bin/bash
set -e

TOKEN=$(aws secretsmanager get-secret-value --secret-id $ADO_AGENT_TOKEN --region us-east-1  --query SecretString --output text | jq -r '.ADO_AGENT_TOKEN')
DIRS=("agent")

for DIR in "${DIRS[@]}"; do 
    DIR_PATH="/home/ubuntu/${DIR}/"
    echo "Running $DIR/config.sh"
    "$DIR_PATH/config.sh" remove --unattended --auth pat --token ${TOKEN}
done