output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret for RDS credentials"
  value       = module.rds.db_secret_arn
}

output "s3_bucket_name" {
  description = "Name of the documents S3 bucket"
  value       = module.s3.bucket_id
}

# Re-exposed from shared cluster
output "eks_cluster_name" {
  description = "EKS cluster name (shared)"
  value       = data.terraform_remote_state.cluster.outputs.eks_cluster_name
}

output "ecr_backend_url" {
  description = "ECR repository URL for the backend (shared)"
  value       = data.terraform_remote_state.cluster.outputs.ecr_backend_url
}

output "ecr_frontend_url" {
  description = "ECR repository URL for the frontend (shared)"
  value       = data.terraform_remote_state.cluster.outputs.ecr_frontend_url
}
