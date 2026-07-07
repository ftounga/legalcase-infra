# ─────────────────────────────────────────────────────────────────────────────
# claude-gateway — dépôts ECR dédiés dans le cluster partagé.
# Réutilise le module ecr (crée claude-gateway-backend + claude-gateway-frontend).
# Ajouté en fichier séparé pour ne pas toucher au socle legalcase.
# ─────────────────────────────────────────────────────────────────────────────

module "ecr_claude_gateway" {
  source = "../modules/ecr"

  project = "claude-gateway"

  tags = { Project = "claude-gateway", ManagedBy = "terraform" }
}

output "claude_gateway_ecr_backend_url" {
  description = "URL du dépôt ECR backend claude-gateway"
  value       = module.ecr_claude_gateway.backend_repository_url
}

output "claude_gateway_ecr_frontend_url" {
  description = "URL du dépôt ECR frontend claude-gateway"
  value       = module.ecr_claude_gateway.frontend_repository_url
}
