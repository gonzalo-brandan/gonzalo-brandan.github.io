# AWS hosting

This site is built with Jekyll and served from AWS. Everything here is Terraform.

```
GitHub push to main
  └─ GitHub Actions: build → htmlproofer → assume IAM role (OIDC, no stored keys)
       └─ aws s3 sync → CloudFront invalidation

Visitor → Route 53 → CloudFront (HTTPS via ACM, security headers, www redirect, index rewrite) → private S3 bucket
```

| File | What it creates |
|---|---|
| `main.tf` | Private S3 bucket, CloudFront distribution with Origin Access Control, bucket policy |
| `index-rewrite.js` | CloudFront Function that redirects `www` to the bare domain and serves `/posts/foo/` from `/posts/foo/index.html` |
| `github.tf` | GitHub OIDC provider and a deploy role limited to this repo's `main` branch |
| `domain.tf` | Route 53 zone, ACM certificate and DNS records for gonzalobrandan.com (registered at Namecheap, nameservers pointed at Route 53) |
| `budget.tf` | Monthly cost budget with email alerts |

State is stored in the S3 bucket `tfstate-936719391198-us-east-1` (versioned, with S3 native locking).

## Usage

```bash
terraform -chdir=infra init
terraform -chdir=infra plan
terraform -chdir=infra apply
```

Deploy from a local machine instead of CI with `./scripts/deploy-aws.sh`.
