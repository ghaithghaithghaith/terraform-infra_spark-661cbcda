# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Remote backend â€” state stored in S3, locking via DynamoDB
# (Provisioned by the bootstrap/ folder)
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
terraform {
  backend "s3" {
    bucket         = "tfstate-infra-spark-le4202es"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tflock-infra-spark-le4202es"
    encrypt        = true
  }
}

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
  lower   = true
}

resource "aws_s3_bucket" "glue_scripts" {
  bucket        = "glue-scripts-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket" "glue_output" {
  bucket        = "glue-output-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_object" "test_glue_script" {
  bucket = aws_s3_bucket.glue_scripts.id
  key    = "jobs/etl_job_test.py"

  # TEST placeholder artifact (must be valid and non-empty)
  content = <<-PY
    print("Hello from TEST Glue ETL script")
  PY

  content_type = "text/x-python"
}

resource "aws_iam_role" "glue_job_role" {
  name = "glue-job-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "glue.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "glue_job_policy" {
  name = "glue-job-policy-${random_string.suffix.result}"
  role = aws_iam_role.glue_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Read the TEST script from the scripts bucket
      {
        Sid    = "ReadGlueScripts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${aws_s3_bucket.glue_scripts.arn}/jobs/etl_job_test.py"
        ]
      },
      # Write transformed results to the output bucket
      {
        Sid    = "WriteGlueOutput"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = [
          "${aws_s3_bucket.glue_output.arn}/*"
        ]
      },
      # Allow Glue to list bucket (commonly required for some S3 operations)
      {
        Sid    = "ListOutputBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.glue_output.arn
        ]
      },
      # CloudWatch logging for job runs
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_glue_job" "etl_job" {
  name     = "etl-job-${random_string.suffix.result}"
  role_arn = aws_iam_role.glue_job_role.arn

  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 2880
  max_retries       = 0

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.glue_scripts.id}/${aws_s3_object.test_glue_script.key}"
  }

  default_arguments = {
    "--job-language" = "python"

    # Pass bucket locations to the script (CI/CD will replace the TEST script with real code)
    "--SCRIPTS_BUCKET" = aws_s3_bucket.glue_scripts.id
    "--OUTPUT_BUCKET" = aws_s3_bucket.glue_output.id

    # Glue standard logging args
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--continuous-log-logGroup"          = "/aws-glue/jobs"
  }

  execution_property {
    max_concurrent_runs = 1
  }
}
