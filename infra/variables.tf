variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Sensitive credentials are intentionally NOT declared here because the user requested
# to use the provided values as-is in terraform.tfvars.
