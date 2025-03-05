#!/bin/bash

if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS CLI is not configured. Please run 'aws configure'."
    exit 1
fi

S3_BUCKET=$(terraform output -raw s3_bucket_name)
LAMBDA_FUNCTION=$(terraform output -raw lambda_function_name)
AWS_REGION=$(aws configure get region)

echo "Creating sample test data..."
echo "date,product,quantity,price" > test-data.csv
echo "2024-01-01,Product A,10,19.99" >> test-data.csv
echo "2024-01-02,Product B,5,29.99" >> test-data.csv
echo "2024-01-03,Product C,15,9.99" >> test-data.csv

echo "Uploading test data to S3..."
aws s3 cp test-data.csv s3://${S3_BUCKET}/test-data.csv

echo "Creating test event for Lambda..."
cat > test-event.json << EOF
{
    "s3_bucket": "${S3_BUCKET}",
    "s3_key": "test-data.csv"
}
EOF

echo "Invoking Lambda function..."
aws lambda invoke \
    --region ${AWS_REGION} \
    --function-name ${LAMBDA_FUNCTION} \
    --payload file://test-event.json \
    --cli-binary-format raw-in-base64-out \
    lambda-response.json

echo "Lambda response:"
cat lambda-response.json

echo "Cleanup..."
rm -f test-data.csv test-event.json lambda-response.json

echo "Test completed."
