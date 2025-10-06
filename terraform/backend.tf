# S3 Backend for Terraform State
#
# NOTE: Before using this backend, you must first create the S3 bucket and DynamoDB table.
# Run the setup-backend.sh script to create these resources automatically.
#
# Uncomment the backend configuration below after running setup-backend.sh:

terraform {
  backend "s3" {
    bucket         = "goldenshell-terraform-state-327331452742"
    key            = "goldenshell/terraform.tfstate"
    region         = "us-east-1"  # Change to your region
    encrypt        = true
    dynamodb_table = "goldenshell-terraform-locks"
  }
}
