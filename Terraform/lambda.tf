data "archive_file" "lambda_top_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_top.zip"

  source {
    content  = <<-EOT
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info("Lambda Superior executada.")
    return {
        "statusCode": 200,
        "body": json.dumps({"status": "success", "message": "Gatilho de transcrição processado."})
    }
EOT
    filename = "index.py"
  }
}

resource "aws_lambda_function" "lambda_top" {
  filename         = data.archive_file.lambda_top_zip.output_path
  function_name    = "${var.project_name}-lambda-transcribe-trigger"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_top_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      S3_BUCKET = local.s3_bucket_name
    }
  }

  tags = {
    Name = "${var.project_name}-lambda-top"
  }
}

data "archive_file" "lambda_formatar_json_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_formatar_json.zip"

  source {
    content  = <<-EOT
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    raw_text = event.get("raw_text", "")
    formatted_payload = {
        "text": raw_text,
        "timestamp": event.get("timestamp"),
        "status": "FORMATTED"
    }
    return {
        "statusCode": 200,
        "body": formatted_payload
    }
EOT
    filename = "index.py"
  }
}

resource "aws_lambda_function" "formatar_json" {
  filename         = data.archive_file.lambda_formatar_json_zip.output_path
  function_name    = "${var.project_name}-formatar-json"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_formatar_json_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  tags = {
    Name = "${var.project_name}-formatar-json"
  }
}

data "archive_file" "lambda_corrigir_transcricao_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_corrigir_transcricao.zip"

  source {
    content  = <<-EOT
import json
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    text_to_correct = event.get("text", "")
    bedrock = boto3.client("bedrock-runtime")
    
    return {
        "statusCode": 200,
        "body": {
            "original_text": text_to_correct,
            "corrected_text": text_to_correct,
            "status": "CORRECTED"
        }
    }
EOT
    filename = "index.py"
  }
}

resource "aws_lambda_function" "corrigir_transcricao" {
  filename         = data.archive_file.lambda_corrigir_transcricao_zip.output_path
  function_name    = "${var.project_name}-corrigir-transcricao"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_corrigir_transcricao_zip.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      BEDROCK_MODEL_ID = "anthropic.claude-3-haiku-20240307-v1:0"
    }
  }

  tags = {
    Name = "${var.project_name}-corrigir-transcricao"
  }
}
