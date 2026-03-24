resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project}/${var.environment}/rds/credentials"
  description             = "RDS PostgreSQL credentials for ${var.project} ${var.environment}"
  recovery_window_in_days = var.environment == "production" ? 30 : 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-${var.environment}-db-subnet-group"
  description = "Subnet group for ${var.project} ${var.environment} RDS"
  subnet_ids  = var.database_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "Allow PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rds-sg"
  })
}

resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  multi_az                  = var.multi_az
  publicly_accessible       = false
  deletion_protection       = var.environment == "production" ? true : false
  skip_final_snapshot       = var.environment == "production" ? false : true
  final_snapshot_identifier = var.environment == "production" ? "${var.project}-${var.environment}-final-snapshot" : null

  backup_retention_period = var.environment == "production" ? 7 : 1
  backup_window           = "02:00-03:00"
  maintenance_window      = "Mon:03:00-Mon:04:00"

  performance_insights_enabled = var.environment == "production" ? true : false

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-postgres"
  })
}
