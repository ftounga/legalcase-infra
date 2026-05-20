output "instance_id" {
  description = "EC2 instance ID — use with `aws ssm start-session --target <id>`"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "EC2 instance ARN"
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "Private IP of the dev workstation (no public IP — connect via SSM)"
  value       = aws_instance.this.private_ip
}

output "instance_profile_arn" {
  description = "IAM instance profile ARN attached to the dev workstation"
  value       = aws_iam_instance_profile.instance.arn
}

output "github_secret_arn" {
  description = "ARN of the Secrets Manager secret holding GitHub credentials. Populate it once with: aws secretsmanager put-secret-value --secret-id <id> --secret-string '{\"github_token\":\"ghp_xxx\",\"github_user\":\"TOUNGA01\"}'"
  value       = aws_secretsmanager_secret.github.arn
}

output "github_secret_id" {
  description = "Name (id) of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.github.id
}

output "ssm_session_command" {
  description = "Ready-to-run command to open an SSM Session"
  value       = "aws ssm start-session --target ${aws_instance.this.id} --region ${data.aws_region.current.name} --profile ${var.aws_cli_profile}"
}

output "ssm_ssh_command" {
  description = "If you want a real ssh tunnel via SSM (port forwarding, scp, etc.), use this with the SSM SSH plugin configured in ~/.ssh/config"
  value       = "ssh ${var.linux_user}@${aws_instance.this.id}"
}
