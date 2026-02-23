# ===========================
# General Configuration
# ===========================

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "s3-lambda-uploader"
}

# ===========================
# S3 Bucket Configuration
# ===========================

variable "bucket_name" {
  description = "Name of the S3 bucket for file uploads (must be globally unique)"
  type        = string
}

variable "upload_folder" {
  description = "Folder path prefix for uploads in S3 bucket (must end with /)"
  type        = string
  default     = "uploads/"

  validation {
    condition     = can(regex("/$", var.upload_folder))
    error_message = "The upload_folder must end with a forward slash (/)."
  }
}

variable "enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = false
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policy to automatically delete old files"
  type        = bool
  default     = false
}

variable "file_expiration_days" {
  description = "Number of days after which uploaded files will be automatically deleted (only used if enable_lifecycle_policy is true)"
  type        = number
  default     = 90
}

# ===========================
# CORS Configuration
# ===========================

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS (use ['*'] for development, specific domains for production)"
  type        = list(string)
  default     = ["*"]
}

variable "allowed_origin" {
  description = "Allowed origin for Lambda CORS headers (use '*' for development, specific domain for production)"
  type        = string
  default     = "*"
}

# ===========================
# Lambda Configuration
# ===========================

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "file-upload-function"
}

variable "lambda_source_dir" {
  description = "Path to the Lambda function source code directory"
  type        = string
  default     = "../src/lambda"
}

variable "lambda_output_path" {
  description = "Path where the Lambda deployment package (zip) will be created"
  type        = string
  default     = "./lambda_function.zip"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 10

  validation {
    condition     = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "filename_separator" {
  description = "Separator between random prefix and original filename"
  type        = string
  default     = "----"
}

# ===========================
# Logging Configuration
# ===========================

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be one of the valid CloudWatch Logs retention periods."
  }
}

# ===========================
# Monitoring Configuration
# ===========================

variable "enable_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = false
}

# ===========================
# Tags
# ===========================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
