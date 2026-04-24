output "glue_job_name" {
  value = aws_glue_job.etl_job.id
}

output "glue_job_arn" {
  value = aws_glue_job.etl_job.arn
}

output "glue_job_role_arn" {
  value = aws_iam_role.glue_job_role.arn
}

output "glue_scripts_bucket_name" {
  value = aws_s3_bucket.glue_scripts.id
}

output "glue_scripts_bucket_arn" {
  value = aws_s3_bucket.glue_scripts.arn
}

output "glue_scripts_test_script_s3_uri" {
  value = "s3://${aws_s3_bucket.glue_scripts.id}/${aws_s3_object.test_glue_script.key}"
}

output "glue_output_bucket_name" {
  value = aws_s3_bucket.glue_output.id
}

output "glue_output_bucket_arn" {
  value = aws_s3_bucket.glue_output.arn
}
