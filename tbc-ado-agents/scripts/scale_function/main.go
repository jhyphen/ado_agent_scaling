package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/autoscaling"
	autoscalingtypes "github.com/aws/aws-sdk-go-v2/service/autoscaling/types"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
)

const (
	dynamoTableName = "AdoScalingLocks"
	lockID          = "ScalingLock"
	coolDownMinutes = 10
)

type BuildQueueResponse struct {
	Count int `json:"count"`
}

type AgentPoolResponse struct {
	Value []struct {
		AssignedRequest interface{} `json:"assignedRequest"`
	} `json:"value"`
}

// AcquireLock attempts to acquire a DynamoDB lock for scaling operations.
func acquireLock(dynamoClient *dynamodb.Client) (bool, error) {
	currentTime := time.Now().Unix()
	expirationTime := currentTime + int64(coolDownMinutes*60)

	input := &dynamodb.PutItemInput{
		TableName: aws.String(dynamoTableName),
		Item: map[string]types.AttributeValue{
			"LockID": &types.AttributeValueMemberS{Value: lockID},
			"ExpiresAt": &types.AttributeValueMemberN{
				Value: strconv.FormatInt(expirationTime, 10),
			},
		},
		ConditionExpression: aws.String("attribute_not_exists(LockID) OR ExpiresAt < :currentTime"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":currentTime": &types.AttributeValueMemberN{Value: strconv.FormatInt(currentTime, 10)},
		},
	}

	_, err := dynamoClient.PutItem(context.TODO(), input)
	if err != nil {
		if isConditionalCheckFailed(err) {
			return false, nil // Lock is currently held
		}
		return false, err // Unexpected error
	}
	return true, nil // Lock acquired
}

// Check if error is ConditionalCheckFailedException
func isConditionalCheckFailed(err error) bool {
	var conditionFailedErr *types.ConditionalCheckFailedException
	return errors.As(err, &conditionFailedErr)
}

// handleScaling scales up the ASG if necessary, respecting the lock mechanism.
func handleScaling(queueLength, currentCapacity, maxCapacity int, dynamoClient *dynamodb.Client, asgClient *autoscaling.Client, asgName string) {
	if queueLength > 0 && currentCapacity < 20 {
		acquired, err := acquireLock(dynamoClient)
		if err != nil {
			log.Fatalf("Error checking or acquiring lock: %v", err)
		}
		if !acquired {
			fmt.Println("Cool down period active. Skipping scale up.")
			return
		}

		newDesiredCapacity := currentCapacity + 5
		if newDesiredCapacity > 20 {
			newDesiredCapacity = 20
		}

		newMaxCapacity := max(maxCapacity, newDesiredCapacity)
		updateAutoScalingGroup(asgClient, asgName, newDesiredCapacity, newMaxCapacity)
		fmt.Printf("Scaled up ASG %s to desired capacity of %d and max capacity of %d\n", asgName, newDesiredCapacity, newMaxCapacity)
	}
}

// Main Lambda handler
func handler(ctx context.Context) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("Unable to load SDK config: %v", err)
	}

	// Initialize AWS clients
	secretsClient := secretsmanager.NewFromConfig(cfg)
	asgClient := autoscaling.NewFromConfig(cfg)
	dynamoClient := dynamodb.NewFromConfig(cfg)

	queues := map[string]map[string]string{
		"test": {
			"poolID":  os.Getenv("TEST_POOL_ID"),
			"asgName": os.Getenv("TEST_ASG_NAME"),
		},
		"deploy": {
			"poolID":  os.Getenv("DEPLOY_POOL_ID"),
			"asgName": os.Getenv("DEPLOY_ASG_NAME"),
		},
		"build": {
			"poolID":  os.Getenv("BUILD_POOL_ID"),
			"asgName": os.Getenv("BUILD_ASG_NAME"),
		},
	}

	adoPAT := getSecret(ctx, secretsClient, os.Getenv("ADO_LAMBDA_PAT_NAME"))
	adoOrg := os.Getenv("ADO_ORG")
	adoProject := os.Getenv("ADO_PROJECT")

	for _, config := range queues {
		queueLength := getQueueLength(config["poolID"], adoOrg, adoProject, adoPAT)
		currentASG := getAutoScalingGroup(ctx, asgClient, config["asgName"])
		currentCapacity := getCapacity(currentASG.DesiredCapacity)
		currentMaxCapacity := getCapacity(currentASG.MaxSize)

		handleScaling(queueLength, currentCapacity, currentMaxCapacity, dynamoClient, asgClient, config["asgName"])
	}
}

// getCapacity safely retrieves capacity values
func getCapacity(capacity *int32) int {
	if capacity == nil {
		return 0
	}
	return int(*capacity)
}

func getQueueLength(poolID, adoOrg, adoProject, adoPAT string) int {
	url := fmt.Sprintf("https://dev.azure.com/%s/%s/_apis/distributedtask/queues?poolIds=%s&api-version=7.2-preview.1", adoOrg, adoProject, poolID)
	resp := makeAzureDevOpsRequest(url, adoPAT)
	var result BuildQueueResponse
	json.Unmarshal(resp, &result)
	return result.Count
}

func getAutoScalingGroup(ctx context.Context, client *autoscaling.Client, asgName string) autoscalingtypes.AutoScalingGroup {
	output, err := client.DescribeAutoScalingGroups(ctx, &autoscaling.DescribeAutoScalingGroupsInput{
		AutoScalingGroupNames: []string{asgName},
	})
	if err != nil || len(output.AutoScalingGroups) == 0 {
		log.Fatalf("Failed to describe ASG: %v", err)
	}
	return output.AutoScalingGroups[0]
}

func updateAutoScalingGroup(client *autoscaling.Client, asgName string, desiredCapacity, maxCapacity int) {
	_, err := client.UpdateAutoScalingGroup(context.TODO(), &autoscaling.UpdateAutoScalingGroupInput{
		AutoScalingGroupName: aws.String(asgName),
		DesiredCapacity:      aws.Int32(int32(desiredCapacity)),
		MaxSize:              aws.Int32(int32(maxCapacity)),
	})
	if err != nil {
		log.Fatalf("Failed to update ASG: %v", err)
	}
}

func makeAzureDevOpsRequest(url, adoPAT string) []byte {
	req, _ := http.NewRequest("GET", url, nil)
	req.SetBasicAuth("", adoPAT)
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Fatalf("Failed to make Azure DevOps request: %v", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return body
}

func getSecret(ctx context.Context, client *secretsmanager.Client, secretName string) string {
	output, err := client.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretName),
	})
	if err != nil {
		log.Fatalf("Failed to retrieve secret: %v", err)
	}
	return *output.SecretString
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func main() {
	lambda.Start(handler)
}
