terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "s3-lambda-uploader"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# ===========================
# S3 Bucket for File Uploads
# ===========================

resource "aws_s3_bucket" "upload_bucket" {
  bucket = var.bucket_name

  tags = {
    Name = "File Upload Bucket"
  }
}

# Enable versioning (optional but recommended for production)
resource "aws_s3_bucket_versioning" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access (uploads are done via pre-signed URLs)
resource "aws_s3_bucket_public_access_block" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration for browser uploads
resource "aws_s3_bucket_cors_configuration" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = []
    max_age_seconds = 3000
  }
}

# Optional lifecycle policy for automatic cleanup
resource "aws_s3_bucket_lifecycle_configuration" "upload_bucket" {
  count  = var.enable_lifecycle_policy ? 1 : 0
  bucket = aws_s3_bucket.upload_bucket.id

  rule {
    id     = "delete-old-uploads"
    status = "Enabled"

    filter {
      prefix = var.upload_folder
    }

    expiration {
      days = var.file_expiration_days
    }
  }
}

# ===========================
# IAM Role for Lambda
# ===========================

# Lambda execution role (best practice - no hardcoded credentials)
resource "aws_iam_role" "lambda_execution" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "Lambda Execution Role"
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Policy for S3 access
resource "aws_iam_role_policy" "lambda_s3_access" {
  name   = "s3-access"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.lambda_s3_access.json
}

data "aws_iam_policy_document" "lambda_s3_access" {
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:PutObjectAcl"
    ]

    resources = [
      "${aws_s3_bucket.upload_bucket.arn}/*"
    ]
  }
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ===========================
# CloudWatch Log Group
# ===========================

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "Lambda Upload Function Logs"
  }
}

# ===========================
# Lambda Function
# ===========================

# Package Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/${var.lambda_source_dir}"
  output_path = "${path.module}/${var.lambda_output_path}"
}

resource "aws_lambda_function" "upload_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      UPLOADBUCKET   = aws_s3_bucket.upload_bucket.id
      UPLOADFOLDER   = var.upload_folder
      FILENAMESEP    = var.filename_separator
      REGION         = var.aws_region
      ALLOWED_ORIGIN = var.allowed_origin
      # Note: No ACCESSKEYID or SECRETACCESSKEY - using IAM role instead
    }
  }

  tags = {
    Name = "Upload URL Generator"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_s3_access
  ]
}

# ===========================
# API Gateway (HTTP API)
# ===========================

resource "aws_apigatewayv2_api" "upload_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "API Gateway for S3 Lambda Uploader"

  cors_configuration {
    allow_origins     = var.cors_allowed_origins
    allow_methods     = ["GET", "OPTIONS"]
    allow_headers     = ["Content-Type", "Accept"]
    max_age           = 300
    allow_credentials = false
  }

  tags = {
    Name = "Upload API Gateway"
  }
}

# Lambda integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.upload_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.upload_function.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Route
resource "aws_apigatewayv2_route" "get_upload_url" {
  api_id    = aws_apigatewayv2_api.upload_api.id
  route_key = "GET /getUploadURL"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Default stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.upload_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name = "Default API Stage"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "API Gateway Logs"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.upload_api.execution_arn}/*/*"
}

# ===========================
# Optional: CloudWatch Alarms
# ===========================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.lambda_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.upload_function.function_name
  }

  tags = {
    Name = "Lambda Error Alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.lambda_function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors lambda throttles"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.upload_function.function_name
  }

  tags = {
    Name = "Lambda Throttle Alarm"
  }
}
