resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  s3_bucket_name = "${var.project_name}-storage-${random_string.bucket_suffix.result}"
}

# Criado via CLI para contornar bloqueio de SCP do AWS Academy no GetObjectLockConfiguration
resource "terraform_data" "app_storage" {
  input = local.s3_bucket_name

  provisioner "local-exec" {
    command = "aws s3api head-bucket --bucket ${self.input} 2>/dev/null || aws s3api create-bucket --bucket ${self.input} --region ${var.aws_region}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rb s3://${self.input} --force 2>/dev/null || true"
  }
}

resource "aws_s3_bucket_cors_configuration" "app_storage_cors" {
  bucket = local.s3_bucket_name

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }

  depends_on = [terraform_data.app_storage]
}

resource "aws_s3_bucket_public_access_block" "app_storage_pab" {
  bucket = local.s3_bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [terraform_data.app_storage]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage_crypto" {
  bucket = local.s3_bucket_name

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  depends_on = [terraform_data.app_storage]
}


resource "aws_efs_file_system" "shared_fs" {
  creation_token   = "${var.project_name}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name = "${var.project_name}-efs"
  }
}

resource "aws_efs_mount_target" "mount_a" {
  file_system_id  = aws_efs_file_system.shared_fs.id
  subnet_id       = aws_subnet.private_3.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "mount_b" {
  file_system_id  = aws_efs_file_system.shared_fs.id
  subnet_id       = aws_subnet.private_4.id
  security_groups = [aws_security_group.efs.id]
}
