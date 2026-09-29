resource "aws_s3_object" "glue_script" {
  bucket      = var.script_bucket_id
  key         = "scripts/${var.job_name}.py"
  source      = var.script_source_path
  source_hash = filemd5(var.script_source_path)
}

resource "aws_glue_job" "job" {
  name     = var.job_name
  role_arn = var.role_arn

  command {
    script_location = "s3://${aws_s3_object.glue_script.bucket}/${aws_s3_object.glue_script.key}"
    python_version  = "3"
  }

  default_arguments = var.default_arguments
  glue_version      = var.glue_version
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers

  tags = var.tags
}

# EventBridge Trigger for S3 Object Created
resource "aws_cloudwatch_event_rule" "s3_trigger" {
  count       = var.trigger_bucket_name != "" ? 1 : 0
  name        = "${var.job_name}-s3-trigger"
  description = "Trigger for Glue Job when object is created in bucket ${var.trigger_bucket_name}"

  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"],
    "detail" : {
      "bucket" : {
        "name" : [var.trigger_bucket_name]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "glue_target" {
  count    = var.trigger_bucket_name != "" ? 1 : 0
  rule     = aws_cloudwatch_event_rule.s3_trigger[0].name
  arn      = aws_glue_job.job.arn
  role_arn = var.role_arn # Role needs permission to start Glue Job from Events
}
