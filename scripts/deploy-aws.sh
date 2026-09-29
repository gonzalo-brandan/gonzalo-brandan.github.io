#!/usr/bin/env bash
# Build the site locally and upload it to AWS (S3 + CloudFront).
# Normally GitHub Actions does this on every push to main.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUCKET="$(terraform -chdir=infra output -raw bucket_name)"
DIST_ID="$(terraform -chdir=infra output -raw distribution_id)"
SITE_URL="$(terraform -chdir=infra output -raw site_url)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT" _config.aws.yml' EXIT

echo "url: \"$SITE_URL\"" > _config.aws.yml
JEKYLL_ENV=production bundle exec jekyll b -d "$OUT" --config _config.yml,_config.aws.yml

aws s3 sync "$OUT" "s3://$BUCKET" --delete --cache-control "public, max-age=300"
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" \
  --query 'Invalidation.Id' --output text

echo "Deployed: $SITE_URL"
