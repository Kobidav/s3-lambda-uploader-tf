# Terraform Deployment for S3 Lambda Uploader

This Terraform configuration provisions all the AWS infrastructure needed for the S3 Lambda Uploader project, including:

- S3 bucket with CORS configuration
- Lambda function with IAM role
- API Gateway (HTTP API)
- CloudWatch Log Groups
- Optional CloudWatch Alarms
- Optional S3 lifecycle policies

## Prerequisites

Before deploying, ensure you have:

1. **Terraform installed** (version >= 1.0)
   ```bash
   terraform --version
   ```
   If not installed, download from [terraform.io](https://www.terraform.io/downloads)

2. **AWS CLI configured** with credentials
   ```bash
   aws configure
   ```
   You'll need an AWS account with permissions to create:
   - S3 buckets
   - Lambda functions
   - IAM roles and policies
   - API Gateway
   - CloudWatch resources

3. **AWS credentials** set up via one of these methods:
   - AWS CLI configuration (`~/.aws/credentials`)
   - Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
   - IAM role (if running on EC2/ECS)

## Quick Start

### 1. Configure Your Deployment

Copy the example configuration file:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update required variables:

```hcl
# REQUIRED: Choose a globally unique bucket name
bucket_name = "my-company-uploads-prod"

# REQUIRED: Set your AWS region
aws_region = "us-west-2"

# REQUIRED for production: Set your domain
cors_allowed_origins = ["https://example.com"]
allowed_origin       = "https://example.com"
```

### 2. Initialize Terraform

Download required providers:

```bash
terraform init
```

### 3. Review the Deployment Plan

Preview what will be created:

```bash
terraform plan
```

Review the output carefully. You should see resources like:
- `aws_s3_bucket.upload_bucket`
- `aws_lambda_function.upload_function`
- `aws_apigatewayv2_api.upload_api`
- IAM roles and policies
- CloudWatch log groups

### 4. Deploy the Infrastructure

Apply the configuration:

```bash
terraform apply
```

Type `yes` when prompted to confirm.

Deployment typically takes 30-60 seconds.

### 5. Configure the Frontend

After deployment completes, Terraform will output your API Gateway endpoint:

```
Outputs:

api_gateway_endpoint = "https://abc123xyz.execute-api.us-west-2.amazonaws.com/getUploadURL"
```

Update your frontend configuration:

1. Open `../src/frontend/config.js`
2. Replace the `apiEndpoint` value with the URL from Terraform output

```javascript
const CONFIG = {
  apiEndpoint: 'https://abc123xyz.execute-api.us-west-2.amazonaws.com/getUploadURL',
  maxFileSizeBytes: 100 * 1024 * 1024, // 100MB
};
```

### 6. Test Your Deployment

1. Open `../src/frontend/upload.html` in a browser
2. Select a file and click "Upload"
3. Check your S3 bucket in the AWS Console for the uploaded file

## Configuration Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `bucket_name` | Globally unique S3 bucket name | `"my-uploads-bucket"` |

### Recommended Variables

| Variable | Description | Default | Production Value |
|----------|-------------|---------|------------------|
| `aws_region` | AWS region | `"us-west-2"` | Your preferred region |
| `cors_allowed_origins` | Allowed origins for CORS | `["*"]` | `["https://example.com"]` |
| `allowed_origin` | Lambda CORS origin | `"*"` | `"https://example.com"` |
| `environment` | Environment name | `"dev"` | `"prod"` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `upload_folder` | S3 prefix for uploads | `"uploads/"` |
| `lambda_timeout` | Lambda timeout (seconds) | `10` |
| `lambda_memory_size` | Lambda memory (MB) | `256` |
| `lambda_source_dir` | Path to Lambda source code | `"../src/lambda"` |
| `lambda_output_path` | Lambda zip output path | `"./lambda_function.zip"` |
| `filename_separator` | Prefix separator | `"----"` |
| `log_retention_days` | CloudWatch log retention | `7` |
| `enable_versioning` | Enable S3 versioning | `false` |
| `enable_lifecycle_policy` | Auto-delete old files | `false` |
| `file_expiration_days` | Days before auto-deletion | `90` |
| `enable_alarms` | Enable CloudWatch alarms | `false` |

## Architecture

This Terraform configuration creates:

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Browser    │─────▶│ API Gateway  │─────▶│   Lambda     │
│  (Frontend)  │      │  (HTTP API)  │      │  Function    │
└──────────────┘      └──────────────┘      └──────┬───────┘
                                                    │
                                                    │ Generates
                                                    │ Pre-signed URL
                                                    ▼
                            ┌──────────────────────────────┐
                            │        S3 Bucket             │
                            │   (Direct Upload via PUT)    │
                            └──────────────────────────────┘
```

### Security Features

1. **IAM Role-based Authentication**: Lambda uses an IAM execution role instead of hardcoded credentials
2. **Pre-signed URLs**: Time-limited URLs (5 minutes) for secure uploads
3. **CORS Protection**: Configurable allowed origins
4. **S3 Public Access Block**: Bucket is not publicly accessible
5. **Server-side Encryption**: AES256 encryption at rest
6. **CloudWatch Logging**: All API and Lambda requests are logged

## Production Best Practices

For production deployments, consider these settings in `terraform.tfvars`:

```hcl
# Use specific domain instead of wildcard
cors_allowed_origins = ["https://example.com", "https://www.example.com"]
allowed_origin       = "https://example.com"

# Enable versioning for data protection
enable_versioning = true

# Enable monitoring
enable_alarms = true
log_retention_days = 30

# Optional: Auto-delete old uploads
enable_lifecycle_policy = true
file_expiration_days    = 90

# Production environment tag
environment = "prod"
```

### Remote State Management

For team environments, use remote state storage:

```hcl
# Add to main.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "s3-lambda-uploader/terraform.tfstate"
    region = "us-west-2"
    encrypt = true
  }
}
```

## Managing Your Deployment

### View Current State

```bash
terraform show
```

### View Outputs

```bash
terraform output
```

### View Specific Output

```bash
terraform output api_gateway_endpoint
```

### Update Configuration

1. Modify `terraform.tfvars`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

### Destroy Resources

To delete all created resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete:
- The S3 bucket (must be empty first)
- Lambda function
- API Gateway
- All logs
- IAM roles

## Troubleshooting

### Issue: "bucket name already exists"

**Cause**: S3 bucket names must be globally unique across all AWS accounts.

**Solution**: Change `bucket_name` in `terraform.tfvars` to something unique.

### Issue: "403 Forbidden" when uploading

**Possible causes**:
1. CORS not configured correctly
2. IAM role lacks S3 permissions
3. Pre-signed URL expired

**Solutions**:
- Check CORS settings match your domain
- Verify IAM role has `s3:PutObject` permission
- Ensure system time is correct (affects URL signing)

### Issue: Lambda timeout errors

**Cause**: Lambda running longer than configured timeout.

**Solution**: Increase `lambda_timeout` in `terraform.tfvars`:

```hcl
lambda_timeout = 30
```

### Issue: CORS errors in browser console

**Cause**: Frontend domain not in `cors_allowed_origins`.

**Solution**: Add your domain to the allowed origins list:

```hcl
cors_allowed_origins = ["https://yourdomain.com"]
allowed_origin       = "https://yourdomain.com"
```

Then run `terraform apply` to update.

### Viewing Logs

Check CloudWatch logs for debugging:

```bash
# Lambda logs
aws logs tail /aws/lambda/file-upload-function --follow

# API Gateway logs
aws logs tail /aws/apigateway/s3-lambda-uploader --follow
```

Or view in the AWS Console (links provided in terraform outputs).

## Cost Estimation

### Monthly Costs (Approximate)

Based on 10,000 uploads per month, 5MB average file size:

| Service | Usage | Estimated Cost |
|---------|-------|----------------|
| Lambda | 10,000 requests @ 256MB, 1s avg | ~$0.20 |
| API Gateway | 10,000 requests | ~$0.01 |
| S3 Storage | 50GB stored | ~$1.15 |
| S3 PUT requests | 10,000 requests | ~$0.05 |
| CloudWatch Logs | 1GB logs | ~$0.50 |
| **Total** | | **~$1.91/month** |

Costs scale with usage. Large files and high volume will increase costs.

Use [AWS Pricing Calculator](https://calculator.aws/) for detailed estimates.

## Advanced Configuration

### Custom Domain

To use a custom domain (e.g., `api.example.com`):

1. Create ACM certificate for your domain
2. Add custom domain to API Gateway
3. Update DNS records

See [AWS documentation](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-custom-domain-names.html) for details.

### Multi-Region Deployment

To deploy in multiple regions:

1. Create separate `terraform.tfvars` files per region
2. Use Terraform workspaces:
   ```bash
   terraform workspace new us-east-1
   terraform workspace new us-west-2
   ```
3. Deploy to each workspace with region-specific variables

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Deploy Terraform
on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: ./terraform
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## File Structure

```
terraform/
├── main.tf                      # Main infrastructure resources
├── variables.tf                 # Input variable definitions
├── outputs.tf                   # Output value definitions
├── terraform.tfvars            # Your configuration (create from example)
├── terraform.tfvars.example    # Example configuration
├── README.md                    # This file
└── lambda_function.zip         # Generated during terraform apply
```

## Support

For issues or questions:

1. Check [INSTRUCTIONS.md](../INSTRUCTIONS.md) for manual setup guidance
2. Review [AWS Documentation](https://aws.amazon.com/documentation/)
3. Open an issue on [GitHub](https://github.com/devondragon/s3-lambda-uploader/issues)

## License

Same license as the parent project.
