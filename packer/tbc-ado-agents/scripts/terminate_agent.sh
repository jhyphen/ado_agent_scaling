#!/bin/bash

#### NOTE POOL_ID and ADO_AGENT_TOKEN set at runtime during ASG deployment in AWSInfrastructure/terraform/tbc-ado-agents

# Variables
PAT=$(aws secretsmanager get-secret-value --secret-id $ADO_AGENT_TOKEN --region us-east-1  --query SecretString --output text | jq -r '.ADO_AGENT_TOKEN')
DIR="agent"
AGENT_NAME="$(hostname)-agent"

# Get Agent ID
AGENT_ID_URL="https://dev.azure.com/$ORG/_apis/distributedtask/pools/${POOL_ID}/agents?api-version=7.2-preview.1"
AGENT_ID=$(curl -u ":${PAT}" "${AGENT_ID_URL}" | jq -r --arg name ${AGENT_NAME} '.value[] | select(.name == $name) | .id')

echo "Agent ID: $AGENT_ID"

# Azure DevOps API URL
API_URL="https://dev.azure.com/${ORG}/_apis/distributedtask/pools/${POOL_ID}/agents/${AGENT_ID}?api-version=7.2-preview.1"

# Max retries and wait time
MAX_RETRIES=6 # Total wait time = MAX_RETRIES * WAIT_TIME
WAIT_TIME=300 # 5 mins in seconds

# Function to check if the agent has a running job
check_agent_job() {
    echo "Checking if agent has a running job..."
    RESPONSE=$(curl -u ":${PAT}" -H "Content-Type: application/json" "$API_URL")

    ASSIGNED_REQUEST=$(echo "$RESPONSE" | jq '.assignedRequest | length')

    if [ "$ASSIGNED_REQUEST" -eq 0 ]; then
        echo "No job is assigned to the agent."
        return 0
    else
        echo "Agent is running a job."
        return 1
    fi
}

# Function to force kill the agent's job
force_kill_job() {
    echo "Force killing the agent's job..."
    JOB_REQUEST_ID=$(curl -s -u ":${PAT}" -H "Content-Type: application/json" "$API_URL" | jq -r '.assignedRequest.requestId')

    if [ -n "$JOB_REQUEST_ID" ]; then
        FORCE_KILL_URL="https://dev.azure.com/${ORG}/_apis/distributedtask/pools/${POOL_ID}/jobrequests/${JOB_REQUEST_ID}/finish?api-version=7.2-preview.1"
        curl -s -u ":${PAT}" -H "Content-Type: application/json" -X POST "$FORCE_KILL_URL" -d '{"result":"canceled"}'
        echo "Job $JOB_REQUEST_ID forcefully terminated."
    else
        echo "No job to force kill."
    fi
}

# Function to stop and uninstall the agent
stop_and_uninstall_agent() {
    echo "Stopping then agent service.."
    DIR_PATH="/home/ubuntu/${DIR}/"
    cd ${DIR_PATH}
    echo "Running $DIR/svc.sh"
    sudo ./svc.sh stop || echo "Failed to stop agent service."
    echo "Uninstalling the agent..."
    sudo ./svc.sh uninstall || echo "Failed to uninstall the agent service."
    echo "Removing Agent configuration..."
    echo "Running $DIR/config.sh"
    "$DIR_PATH/config.sh" remove --unattended --auth pat --token ${PAT}
}

# Attempt to remove agents
retry_count=0
while [ "$retry_count" -lt "$MAX_RETRIES" ]; do
    if check_agent_job; then
        echo "Proceeding with agent cleanup..."
        stop_and_uninstall_agent
        exit 0
    fi

    echo "Agent is still running a job. Retrying in $WAIT_TIME seconds... ($((retry_count + 1))/$MAX_RETRIES)"
    sleep "$WAIT_TIME"
    retry_count=$((retry_count + 1))
done

echo "Job still running after $((MAX_RETRIES * WAIT_TIME / 60)) minutes. Forcefully terminating job..."
force_kill_job
stop_and_uninstall_agent
