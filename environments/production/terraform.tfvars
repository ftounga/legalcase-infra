project = "legalcase"
region  = "eu-west-3"

# Networking
vpc_cidr              = "10.1.0.0/16"
public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs  = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
database_subnet_cidrs = ["10.1.20.0/24", "10.1.21.0/24", "10.1.22.0/24"]

# EKS
kubernetes_version = "1.31"
node_instance_type = "t3.medium"
node_desired_size  = 2
node_min_size      = 2
node_max_size      = 4

# RDS
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 50
db_max_allocated_storage = 200

# S3
s3_allowed_origins = ["*"]
