project = "legalcase"
region  = "eu-west-3"

# Networking
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

# EKS
kubernetes_version = "1.31"
node_instance_type = "t3.medium"
node_desired_size  = 1
node_min_size      = 1
node_max_size      = 2

# RDS
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 50

# S3
s3_allowed_origins = ["*"]
