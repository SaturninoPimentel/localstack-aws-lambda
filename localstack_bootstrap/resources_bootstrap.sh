#!/usr/bin/env bash
set -euo pipefail
# enable debug
# set -x
create_queue() {
    echo "configuring sqs"
    QUEUE_NAME=$1
    aws sqs create-queue --queue-name ${QUEUE_NAME} \
    --attributes VisibilityTimeout=30 --endpoint-url=http://${LOCALSTACK_HOST}:4566
}
create_sns(){
    echo "Create SNS Topic"
    TOPIC_NAME=$1
    aws sns create-topic --name ${TOPIC_NAME} \
    --endpoint-url http://${LOCALSTACK_HOST}:4566
    
    echo "Subscribe Queue to Topic"
    aws sns subscribe --topic-arn arn:aws:sns:${AWS_DEFAULT_REGION}:000000000000:${TOPIC_NAME} \
    --protocol sqs --notification-endpoint arn:aws:sqs:${AWS_DEFAULT_REGION}:000000000000:${QUEUE_NAME} \
    --endpoint-url http://${LOCALSTACK_HOST}:4566
}

create_s3(){
    echo "Configuring S3"
    
    echo "Create admin"
    aws iam create-role --role-name admin-role --path / \
    --endpoint-url=http://${LOCALSTACK_HOST}:4566 \
    --assume-role-policy-document file:./admin-policy.json
    echo "Make S3 bucket"
    aws s3 mb s3://lambda-functions --endpoint-url=http://${LOCALSTACK_HOST}:4566
    
    echo "Copy the lambda function to the S3 bucket"
    aws s3 cp ./lambda.zip s3://lambda-functions \
    --endpoint-url=http://${LOCALSTACK_HOST}:4566
}

create_lambda(){
    create_s3
    create_queue "sns-queue-test"
    create_sns "sns-topic-test"
    
    echo "Create the lambda"
    LAMBDA_NAME=$1
    aws lambda create-function --function-name ${LAMBDA_NAME} \
    --role arn:aws:iam::000000000000:role/admin-role --code S3Bucket=lambda-functions,S3Key=lambda.zip \
    --handler main --runtime go1.x \
    --description "SQS Lambda handler for test sqs." --timeout 60 --memory-size 128 \
    --endpoint-url=http://${LOCALSTACK_HOST}:4566
    echo "Map the ${QUEUE_NAME} to the lambda function"
    aws lambda create-event-source-mapping --function-name ${LAMBDA_NAME} \
    --batch-size 1 --event-source-arn "arn:aws:sqs:${AWS_DEFAULT_REGION}:000000000000:${QUEUE_NAME}" \
    --function-response-types "ReportBatchItemFailures" --endpoint-url=http://${LOCALSTACK_HOST}:4566
    
    echo "All resources were initialized!"
}

create_lambda "aws-lambda-test"