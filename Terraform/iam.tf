# roles do ambiente do aws academy
data "aws_iam_role" "lab_role" {
  name = var.lab_role_name
}

data "aws_iam_instance_profile" "lab_profile" {
  name = var.lab_instance_profile_name
}

