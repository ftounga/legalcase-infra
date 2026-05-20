output "instance_id" {
  description = "ID de l'instance EC2 — utiliser avec `aws ssm start-session --target <id>`"
  value       = module.dev_workstation.instance_id
}

output "private_ip" {
  description = "IP privée (pas d'IP publique — connexion exclusivement via SSM)"
  value       = module.dev_workstation.private_ip
}

output "github_secret_arn" {
  description = "ARN du secret Secrets Manager pour les credentials GitHub. Le populer une fois avec : aws secretsmanager put-secret-value --secret-id <id> --secret-string '{\"github_token\":\"ghp_xxx\",\"github_user\":\"TOUNGA01\"}'"
  value       = module.dev_workstation.github_secret_arn
}

output "github_secret_id" {
  description = "Nom (id) du secret Secrets Manager"
  value       = module.dev_workstation.github_secret_id
}

output "ssm_session_command" {
  description = "Commande prête à coller pour ouvrir une session SSM"
  value       = module.dev_workstation.ssm_session_command
}
