locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ─── AMI : Ubuntu 24.04 LTS amd64 (Canonical) ────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── Secrets Manager : credentials GitHub (PAT) ──────────────────────────────
# Le secret est créé vide par Terraform ; sa valeur (PAT GitHub) est posée
# manuellement avec `aws secretsmanager put-secret-value` (voir README).
# Format attendu : {"github_token":"ghp_xxx","github_user":"TOUNGA01"}
resource "aws_secretsmanager_secret" "github" {
  name                    = "${local.name_prefix}/github-credentials"
  description             = "GitHub PAT consumed by cloud-init to configure gh + git credential helper"
  recovery_window_in_days = 0

  tags = var.tags
}

# ─── IAM : rôle d'instance ───────────────────────────────────────────────────
data "aws_iam_policy_document" "instance_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${local.name_prefix}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role.json
  tags               = var.tags
}

# SSM Session Manager (connexion sans SSH ouvert)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Accès AWS de la dev box : équivalent du profil local du développeur.
# AdministratorAccess est attaché parce qu'on veut une parité 1:1 avec le
# workflow local (terraform apply sur l'ensemble de l'infra, kubectl/eks,
# debug IAM/EKS/RDS, etc.). À restreindre si la dev box devient partagée.
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.instance.name
  tags = var.tags
}

# ─── Security Group : egress only ────────────────────────────────────────────
# Pas de port d'entrée — toutes les connexions passent par SSM Session Manager.
resource "aws_security_group" "instance" {
  name        = "${local.name_prefix}-sg"
  description = "Dev workstation - egress only (connections via SSM)"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-sg"
  })
}

# ─── cloud-init ──────────────────────────────────────────────────────────────
data "cloudinit_config" "user_data" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init.yaml", {
      linux_user      = var.linux_user
      git_user_name   = var.git_user_name
      git_user_email  = var.git_user_email
      repos_to_clone  = var.repos_to_clone
      secret_id       = aws_secretsmanager_secret.github.id
      region          = data.aws_region.current.name
      aws_cli_profile = var.aws_cli_profile
    })
  }
}

data "aws_region" "current" {}

# ─── EC2 instance ────────────────────────────────────────────────────────────
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.instance.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name
  user_data_base64       = data.cloudinit_config.user_data.rendered

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size           = var.ebs_volume_size
    volume_type           = var.ebs_volume_type
    encrypted             = true
    delete_on_termination = true

    tags = merge(var.tags, {
      Name = "${local.name_prefix}-root"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}"
  })

  # Une fois lancée, on ne veut pas que Terraform re-pousse le user-data
  # à chaque rebuild d'AMI ni qu'il force un remplacement si on stoppe/redémarre.
  lifecycle {
    ignore_changes = [
      ami,
      user_data_base64,
    ]
  }
}

# ─── Auto-stop : EventBridge Scheduler → ec2:StopInstances ───────────────────
data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "auto_stop" {
  name               = "${local.name_prefix}-auto-stop-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "auto_stop" {
  name = "${local.name_prefix}-auto-stop-policy"
  role = aws_iam_role.auto_stop.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:StopInstances"]
      Resource = aws_instance.this.arn
    }]
  })
}

resource "aws_scheduler_schedule" "auto_stop" {
  name        = "${local.name_prefix}-auto-stop"
  description = "Stop ${local.name_prefix} every night"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.auto_stop_cron
  schedule_expression_timezone = "Europe/Paris"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.auto_stop.arn

    input = jsonencode({
      InstanceIds = [aws_instance.this.id]
    })
  }
}
