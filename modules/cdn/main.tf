# ─── Origin Access Control (OAC) ──────────────────────────────────────────────
# OAC moderne remplaçant Origin Access Identity (OAI legacy). Permet à
# CloudFront de signer les requêtes vers S3 en SigV4. Compatible avec un
# bucket privé (public access fully blocked).
resource "aws_cloudfront_origin_access_control" "documents" {
  name                              = "${var.project}-${var.environment}-documents-oac"
  description                       = "OAC for ${var.project} ${var.environment} documents bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ─── CloudFront distribution ──────────────────────────────────────────────────
# V1 : pas de cache (cache policy = CachingDisabled) pour ne pas casser les
# presigned URLs (signature change à chaque génération). Bénéfices V1 :
# - TLS termination au POP (Paris/Marseille/Amsterdam/Bruxelles/Madrid)
# - Réduction latence de 50-150 ms pour les utilisateurs hors région
# - Économie sur le NAT Gateway egress (CloudFront facture moins cher)
# V2 (post-validation traction) : activer un cache policy custom qui cache
# les téléchargements directs tout en laissant passer les presigned URLs.
resource "aws_cloudfront_distribution" "documents" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project}-${var.environment}-documents"
  price_class         = var.price_class
  http_version        = "http2"
  default_root_object = ""

  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "s3-${var.s3_bucket_id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.documents.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${var.s3_bucket_id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Managed policies AWS (IDs stables, documentés) :
    # - CachingDisabled : TTL 0, no cache (compatible presigned URLs)
    # - CORS-S3Origin : forward headers nécessaires à un origin S3 + CORS
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-documents-cdn"
  })
}

# ─── S3 bucket policy : autoriser CloudFront via OAC ──────────────────────────
# La policy n'autorise QUE la distribution CloudFront via aws:SourceArn.
# Compatible avec public_access_block (restrict_public_buckets=true) car
# CloudFront signe les requêtes en sigv4 — accès authentifié, pas public.
data "aws_iam_policy_document" "documents_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${var.s3_bucket_arn}/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.documents.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "documents" {
  bucket = var.s3_bucket_id
  policy = data.aws_iam_policy_document.documents_bucket_policy.json
}
