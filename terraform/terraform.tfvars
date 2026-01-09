# -----------------------------------------------------------------------------
# Terraform Variables - Edit these values for your environment
# -----------------------------------------------------------------------------

aws_region   = "us-east-1"
project_name = "dms-poc"
environment  = "dev"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

# RDS Configuration
db_instance_class    = "db.t3.micro"
db_engine_version    = "15.10"
db_name              = "ecommerce"
db_username          = "dbadmin"
db_password          = "ChangeMe123!"  # Change this in production!
db_allocated_storage = 20

# DMS Configuration
dms_instance_class    = "dms.t3.micro"
dms_allocated_storage = 50
dms_engine_version    = "3.5.4"

# Tags
tags = {
  Project     = "DMS-POC"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Purpose     = "Database Migration Demo"
}
