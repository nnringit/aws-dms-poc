# -----------------------------------------------------------------------------
# RDS Instances - Source and Target Databases
# -----------------------------------------------------------------------------

# Parameter Group for PostgreSQL (enable logical replication for DMS)
resource "aws_db_parameter_group" "postgresql" {
  name        = "${var.project_name}-postgresql-params"
  family      = "postgres15"
  description = "PostgreSQL parameter group for DMS migration"

  # Enable logical replication for DMS
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "wal_sender_timeout"
    value        = "0"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_wal_senders"
    value        = "10"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_replication_slots"
    value        = "10"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.project_name}-postgresql-params"
  }
}

# Source RDS PostgreSQL Instance
resource "aws_db_instance" "source" {
  identifier     = "${var.project_name}-source-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.public.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgresql.name

  publicly_accessible = true
  multi_az            = false
  skip_final_snapshot = true

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled = false
  deletion_protection          = false

  tags = {
    Name = "${var.project_name}-source-db"
    Role = "Source"
  }
}

# Target RDS PostgreSQL Instance
resource "aws_db_instance" "target" {
  identifier     = "${var.project_name}-target-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.public.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgresql.name

  publicly_accessible = true
  multi_az            = false
  skip_final_snapshot = true

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled = false
  deletion_protection          = false

  tags = {
    Name = "${var.project_name}-target-db"
    Role = "Target"
  }
}
