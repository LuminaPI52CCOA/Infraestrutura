resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "bucket" {
  bucket        = "${var.bucket_name}-${random_string.suffix.result}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count  = var.enable_event_notification ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  eventbridge = true
}
