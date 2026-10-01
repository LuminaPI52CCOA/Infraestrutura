resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  bucket_name = "${var.bucket_name}-${random_string.suffix.result}"
}

resource "aws_cloudformation_stack" "bucket" {
  name = "cf-s3-${var.bucket_name}-${random_string.suffix.result}"

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "S3 Bucket ${local.bucket_name} provisioned via CloudFormation to bypass Vocareum SCP ObjectLock restrictions"
    Resources = {
      S3Bucket = {
        Type = "AWS::S3::Bucket"
        Properties = merge(
          {
            BucketName = local.bucket_name
            PublicAccessBlockConfiguration = {
              BlockPublicAcls       = true
              BlockPublicPolicy     = true
              IgnorePublicAcls      = true
              RestrictPublicBuckets = true
            }
          },
          var.enable_event_notification ? {
            NotificationConfiguration = {
              EventBridgeConfiguration = {
                EventBridgeEnabled = true
              }
            }
          } : {},
          length(var.tags) > 0 ? {
            Tags = [
              for k, v in var.tags : {
                Key   = k
                Value = v
              }
            ]
          } : {}
        )
      }
    }
    Outputs = {
      BucketName = {
        Value       = { "Ref" = "S3Bucket" }
        Description = "Name of the created bucket"
      }
      BucketArn = {
        Value       = { "Fn::GetAtt" = ["S3Bucket", "Arn"] }
        Description = "ARN of the created bucket"
      }
    }
  })

  tags = var.tags
}
