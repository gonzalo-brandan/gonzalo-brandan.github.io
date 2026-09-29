# AWS hosting

This site is built with Jekyll and served from AWS. Everything here is Terraform.

```
GitHub push to main
  └─ GitHub Actions: build → htmlproofer → assume IAM role (OIDC, no stored keys)
       └─ aws s3 sync → CloudFront invalidation

Visitor → CloudFront (HTTPS, security headers, index rewrite) → private S3 bucket
```

| File | What it creates |
|---|---|
| `main.tf` | Private S3 bucket, CloudFront distribution with Origin Access Control, bucket policy |
| `index-rewrite.js` | CloudFront Function that serves `/posts/foo/` from `/posts/foo/index.html` |
| `github.tf` | GitHub OIDC provider and a deploy role limited to this repo's `main` branch |
| `budget.tf` | Monthly cost budget with email alerts |

State is stored in the S3 bucket `tfstate-936719391198-us-east-1` (versioned, with S3 native locking).

## Usage

```bash
terraform -chdir=infra init
terraform -chdir=infra plan
terraform -chdir=infra apply
```

Deploy from a local machine instead of CI with `./scripts/deploy-aws.sh`.
