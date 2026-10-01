output "bucket_id" {
  value       = aws_cloudformation_stack.bucket.outputs["BucketName"]
  description = "The name of the bucket"
}

output "bucket_arn" {
  value       = aws_cloudformation_stack.bucket.outputs["BucketArn"]
  description = "The ARN of the bucket"
}

output "bucket_name" {
  value       = aws_cloudformation_stack.bucket.outputs["BucketName"]
  description = "The name of the bucket"
}
