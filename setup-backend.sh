#!/bin/bash

# Script to set up S3 backend for Terraform state storage
# This creates an S3 bucket and DynamoDB table for state locking

set -e

# Configuration
REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="goldenshell-terraform-state-$(aws sts get-caller-identity --query Account --output text)"
DYNAMODB_TABLE="goldenshell-terraform-locks"

echo "Setting up Terraform backend infrastructure..."
echo "Region: $REGION"
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo ""

# Create S3 bucket for state storage
echo "Creating S3 bucket..."
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket $BUCKET_NAME already exists"
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "Bucket created successfully"
fi

# Enable versioning
echo "Enabling bucket versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# Enable encryption
echo "Enabling bucket encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Add bucket policy to enforce SSL
echo "Adding bucket policy to enforce SSL..."
aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Sid\": \"EnforcedTLS\",
            \"Effect\": \"Deny\",
            \"Principal\": \"*\",
            \"Action\": \"s3:*\",
            \"Resource\": [
                \"arn:aws:s3:::$BUCKET_NAME\",
                \"arn:aws:s3:::$BUCKET_NAME/*\"
            ],
            \"Condition\": {
                \"Bool\": {
                    \"aws:SecureTransport\": \"false\"
                }
            }
        }]
    }"

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" >/dev/null 2>&1; then
    echo "DynamoDB table $DYNAMODB_TABLE already exists"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --tags Key=Project,Value=GoldenShell Key=ManagedBy,Value=Terraform

    echo "Waiting for DynamoDB table to be created..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
    echo "DynamoDB table created successfully"
fi

echo ""
echo "✅ Backend infrastructure created successfully!"
echo ""
echo "Next steps:"
echo "1. Edit terraform/backend.tf and uncomment the backend configuration block"
echo "2. Update the region in backend.tf to match your AWS region: $REGION"
echo "3. Update the bucket name to: $BUCKET_NAME"
echo "4. Run 'cd terraform && terraform init' to migrate your state to S3"
echo ""
