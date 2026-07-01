# ─────────────────────────────────────────────────────────────────────────────
# claude-gateway — ressources AWS staging (workspace dédié).
# Réutilise les data sources / locals définis dans main.tf de ce même module
# (data.aws_caller_identity.current, data.aws_iam_openid_connect_provider.eks,
#  local.oidc_issuer, local.environment, local.common_tags).
#
# NB : la base de données claude-gateway est créée sur l'instance RDS PARTAGÉE
# (module.rds de legalcase) — nouvelle base `claudegatewaydb` + rôle dédié,
# provisionnés hors Terraform via un Job Kubernetes (RDS privé, non joignable
# depuis le poste). Voir claude-gateway (repo) : scripts/create-rds-database.sh.
# ─────────────────────────────────────────────────────────────────────────────

# Bucket S3 dédié aux uploads claude-gateway
module "s3_claude_gateway" {
  source = "../../modules/s3"

  project     = "claude-gateway"
  environment = local.environment
  account_id  = data.aws_caller_identity.current.account_id

  allowed_origins = ["https://portal.ng-itconsulting.com"]

  tags = merge(local.common_tags, { App = "claude-gateway" })
}

locals {
  cg_s3_bucket_arn = "arn:aws:s3:::claude-gateway-${local.environment}-documents-${data.aws_caller_identity.current.account_id}"
}

# IRSA — le ServiceAccount claude-gateway-backend du namespace claude-gateway-staging
data "aws_iam_policy_document" "cg_irsa_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:claude-gateway-${local.environment}:claude-gateway-backend"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cg_backend_irsa" {
  name               = "claude-gateway-backend-${local.environment}-irsa"
  assume_role_policy = data.aws_iam_policy_document.cg_irsa_assume_role.json
  tags               = merge(local.common_tags, { App = "claude-gateway" })
}

resource "aws_iam_role_policy" "cg_backend_s3" {
  name = "claude-gateway-backend-${local.environment}-s3-policy"
  role = aws_iam_role.cg_backend_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
      ]
      Resource = [
        local.cg_s3_bucket_arn,
        "${local.cg_s3_bucket_arn}/*",
      ]
    }]
  })
}

# OCR — AWS Textract (images sync + PDF async).
resource "aws_iam_role_policy" "cg_backend_textract" {
  name = "claude-gateway-backend-${local.environment}-textract-policy"
  role = aws_iam_role.cg_backend_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "textract:DetectDocumentText",
        "textract:AnalyzeDocument",
        "textract:StartDocumentTextDetection",
        "textract:GetDocumentTextDetection",
      ]
      Resource = "*"
    }]
  })
}

output "claude_gateway_irsa_role_arn" {
  description = "ARN du rôle IRSA claude-gateway (à injecter dans k8s : IRSA_ROLE_ARN_PLACEHOLDER)"
  value       = aws_iam_role.cg_backend_irsa.arn
}

output "claude_gateway_s3_bucket" {
  description = "Nom du bucket S3 uploads claude-gateway"
  value       = module.s3_claude_gateway.bucket_id
}

output "claude_gateway_rds_secret_arn" {
  description = "ARN du secret Secrets Manager des credentials RDS master (pour créer la base claudegatewaydb)"
  value       = module.rds.db_secret_arn
}
