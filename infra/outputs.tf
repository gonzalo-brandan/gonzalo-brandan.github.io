output "bucket_name" {
  value = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "site_url" {
  value = "https://${var.domain_name}"
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

output "route53_nameservers" {
  description = "Set these as custom DNS nameservers at the domain registrar."
  value       = aws_route53_zone.site.name_servers
}
