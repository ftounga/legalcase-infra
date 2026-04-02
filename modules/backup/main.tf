# ─── IAM Role — AWS Backup ────────────────────────────────────────────────────
data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.project}-${var.environment}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "backup_restore_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup.name
}

# ─── Backup Vault ─────────────────────────────────────────────────────────────
resource "aws_backup_vault" "main" {
  name = "${var.project}-${var.environment}-backup-vault"
  tags = var.tags
}

# ─── Backup Plan ──────────────────────────────────────────────────────────────
resource "aws_backup_plan" "rabbitmq_pvc" {
  name = "${var.project}-${var.environment}-rabbitmq-pvc-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)" # 02:00 UTC daily

    lifecycle {
      delete_after = var.backup_retention_days
    }
  }

  tags = var.tags
}

# ─── Backup Selection — RabbitMQ PVC (EBS volume tagged by EBS CSI driver) ───
resource "aws_backup_selection" "rabbitmq_pvc" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project}-${var.environment}-rabbitmq-pvc"
  plan_id      = aws_backup_plan.rabbitmq_pvc.id

  # The EBS CSI driver automatically tags EBS volumes with the PVC name
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "kubernetes.io/created-for/pvc/name"
    value = "rabbitmq-data"
  }
}
