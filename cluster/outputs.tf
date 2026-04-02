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

output "ecr_backend_url" {
  value = module.ecr.backend_repository_url
}

output "ecr_frontend_url" {
  value = module.ecr.frontend_repository_url
}

output "cluster_autoscaler_role_arn" {
  value       = module.eks.cluster_autoscaler_role_arn
  description = "ARN of the IAM role for Cluster Autoscaler — use as CA_IRSA_ROLE_ARN_PLACEHOLDER in k8s/system/cluster-autoscaler.yaml"
}
