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

variable "github_sub_prefix" {
  description = "OIDC subject prefix of the repo allowed to deploy. Get it with: gh api repos/OWNER/REPO/actions/oidc/customization/sub"
  type        = string
  default     = "repo:gonzalo-brandan@108426175/gonzalo-brandan.github.io@1106601850"
}

variable "create_github_oidc_provider" {
  description = "Set to false if your AWS account already has the GitHub OIDC provider."
  type        = bool
  default     = true
}
