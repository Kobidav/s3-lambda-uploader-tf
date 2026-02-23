# ===========================
# Important Outputs
# ===========================

output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL - Configure this in src/frontend/config.js"
  value       = "${aws_apigatewayv2_api.upload_api.api_endpoint}/getUploadURL"
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.upload_api.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for uploads"
  value       = aws_s3_bucket.upload_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.upload_bucket.arn
}

output "s3_bucket_region" {
  description = "Region where the S3 bucket is located"
  value       = aws_s3_bucket.upload_bucket.region
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.upload_function.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.upload_function.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "cloudwatch_log_group_lambda" {
  description = "CloudWatch Log Group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "cloudwatch_log_group_api_gateway" {
  description = "CloudWatch Log Group for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway_logs.name
}

# ===========================
# Frontend Configuration
# ===========================

output "frontend_config" {
  description = "Configuration snippet for src/frontend/config.js"
  value = <<-EOT

  ╔══════════════════════════════════════════════════════════════════╗
  ║  Frontend Configuration                                          ║
  ╚══════════════════════════════════════════════════════════════════╝

  Update src/frontend/config.js with the following:

  const CONFIG = {
    apiEndpoint: '${aws_apigatewayv2_api.upload_api.api_endpoint}/getUploadURL',
    maxFileSizeBytes: 100 * 1024 * 1024, // 100MB default
  };

  ╔══════════════════════════════════════════════════════════════════╗
  ║  Testing Your Deployment                                         ║
  ╚══════════════════════════════════════════════════════════════════╝

  1. Update the config.js file with the API endpoint above
  2. Open src/frontend/upload.html in a browser
  3. Upload a test file
  4. Check your S3 bucket: ${aws_s3_bucket.upload_bucket.id}
  5. Files will appear in: ${var.upload_folder}

  ╔══════════════════════════════════════════════════════════════════╗
  ║  AWS Console Links                                               ║
  ╚══════════════════════════════════════════════════════════════════╝

  S3 Bucket:
    https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.upload_bucket.id}

  Lambda Function:
    https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${aws_lambda_function.upload_function.function_name}

  API Gateway:
    https://${var.aws_region}.console.aws.amazon.com/apigateway/main/apis/${aws_apigatewayv2_api.upload_api.id}/resources?api=${aws_apigatewayv2_api.upload_api.id}&region=${var.aws_region}

  CloudWatch Logs (Lambda):
    https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.lambda_logs.name, "/", "$252F")}

  EOT
}

# ===========================
# Resource Information
# ===========================

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    s3_bucket          = aws_s3_bucket.upload_bucket.id
    lambda_function    = aws_lambda_function.upload_function.function_name
    api_endpoint       = "${aws_apigatewayv2_api.upload_api.api_endpoint}/getUploadURL"
    aws_region         = var.aws_region
    upload_folder      = var.upload_folder
    versioning_enabled = var.enable_versioning
    alarms_enabled     = var.enable_alarms
  }
}
