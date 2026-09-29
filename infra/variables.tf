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

variable "budget_alert_email" {
  description = "Email address that receives billing alerts."
  type        = string
  default     = "gonzalobrandan@outlook.de"
}

variable "budget_limit_amount" {
  description = "Monthly budget in USD (AWS Budgets only supports USD). 3.40 USD is about 3 EUR."
  type        = string
  default     = "3.40"
}

variable "budget_warning_amount" {
  description = "Early-warning alert in USD when actual spend passes it. 1.10 USD is about 1 EUR."
  type        = string
  default     = "1.10"
}
