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
