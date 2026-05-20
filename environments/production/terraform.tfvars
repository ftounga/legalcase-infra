project = "legalcase"
region  = "eu-west-3"

# RDS
db_instance_class        = "db.t4g.small"
db_allocated_storage     = 50
db_max_allocated_storage = 200

# S3
s3_allowed_origins = ["*"]

# Monitoring
alert_email        = "tounga.franck@ng-itconsulting.com"
monthly_budget_usd = 500
