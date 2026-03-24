output "vpc_id" {
  value = module.networking.vpc_id
}

output "database_subnet_ids" {
  value = module.networking.database_subnet_ids
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA trust policies"
  value       = module.eks.cluster_oidc_issuer_url
}

output "ecr_backend_url" {
  value = module.ecr.backend_repository_url
}

output "ecr_frontend_url" {
  value = module.ecr.frontend_repository_url
}
