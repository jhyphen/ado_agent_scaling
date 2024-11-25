import boto3
import json
import time

# Initialize SSM client
ssm_client = boto3.client('ssm')

def lambda_handler(event, context):
    try:
        # Extract SNS message
        sns_message = event['Records'][0]['Sns']['Message']
        print(f"Raw SNS message: {sns_message}")

        # Parse the JSON message
        message = json.loads(sns_message)

        # Extract EC2 Instance ID from the message
        instance_id = message.get('EC2InstanceId')
        if not instance_id:
            raise KeyError("EC2InstanceId not found in the message")

        print(f"Processing instance ID: {instance_id}")

        # Invoke SSM Run Command
        response = ssm_client.send_command(
            InstanceIds=[instance_id],
            DocumentName="terminate-agent",
            Comment="ASG termination script execution"
        )
        print(f"SSM command sent successfully: {response['Command']['CommandId']}")
        return {"status": "success", "details": json.loads(json.dumps(response, default=str))}

    except KeyError as e:
        print(f"Missing key in message: {e}")
        return {"status": "error", "message": f"KeyError: {e}"}
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        return {"status": "error", "message": f"JSONDecodeError: {e}"}
    except Exception as e:
        print(f"Error invoking SSM Run Command: {e}")
        return {"status": "error", "message": str(e)}