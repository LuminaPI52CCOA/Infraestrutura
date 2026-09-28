resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = var.public_key != "" ? var.public_key : file("${path.module}/lumina-deploy-key.pub")

  tags = {
    Name = var.key_name
  }
}
