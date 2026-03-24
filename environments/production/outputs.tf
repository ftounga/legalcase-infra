output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

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

output "ecr_backend_url" {
  description = "ECR repository URL for the backend"
  value       = module.ecr.backend_repository_url
}

output "ecr_frontend_url" {
  description = "ECR repository URL for the frontend"
  value       = module.ecr.frontend_repository_url
}
