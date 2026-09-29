variable "region" {
  description = "AWS region for the S3 bucket."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for resource names (lowercase letters, numbers, hyphens)."
  type        = string
  default     = "portfolio"
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy, as owner/name."
  type        = string
  default     = "gonzalo-brandan/gonzalo-brandan.github.io"
}

variable "create_github_oidc_provider" {
  description = "Set to false if your AWS account already has the GitHub OIDC provider."
  type        = bool
  default     = true
}
