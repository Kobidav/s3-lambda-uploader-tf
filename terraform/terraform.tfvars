# ===========================
# Required Variables
# ===========================

# IMPORTANT: S3 bucket names must be globally unique across ALL AWS accounts
# Choose a unique name like: my-company-file-uploads-prod
bucket_name = "my-file-upload-bucket"

# ===========================
# General Configuration
# ===========================

# AWS region where resources will be created
aws_region = "us-west-2"

# Environment name (dev, staging, prod)
environment = "dev"

# Project name used for resource naming
project_name = "s3-lambda-uploader"

# ===========================
# S3 Configuration
# ===========================

# Folder path prefix for uploads (must end with /)
upload_folder = "uploads/"

# Enable S3 versioning (recommended for production)
enable_versioning = false

# Enable automatic file deletion after specified days
enable_lifecycle_policy = false
file_expiration_days    = 90

# ===========================
# CORS Configuration
# ===========================

# IMPORTANT: For production, replace "*" with your actual domain(s)
# Development example (allow all origins):
cors_allowed_origins = ["*"]
allowed_origin       = "*"

# Production example (restrict to specific domains):
# cors_allowed_origins = ["https://example.com", "https://www.example.com"]
# allowed_origin       = "https://example.com"

# ===========================
# Lambda Configuration
# ===========================

lambda_function_name = "file-upload-function"
lambda_timeout       = 10
lambda_memory_size   = 256

# Path to Lambda source code (relative to terraform directory)
lambda_source_dir = "../src/lambda"

# Path where the Lambda zip package will be created (relative to terraform directory)
lambda_output_path = "./lambda_function.zip"

# Separator between random prefix and filename
# Example: abc123----myfile.pdf
filename_separator = "----"

# ===========================
# Logging & Monitoring
# ===========================

# CloudWatch log retention (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, etc.)
log_retention_days = 7

# Enable CloudWatch alarms for monitoring (recommended for production)
enable_alarms = false

# ===========================
# Additional Tags (Optional)
# ===========================

additional_tags = {
  Owner       = "DevOps Team"
  CostCenter  = "Engineering"
  Application = "File Uploader"
}
