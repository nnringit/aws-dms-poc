# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

# Source RDS Outputs
output "source_db_endpoint" {
  description = "Source RDS instance endpoint"
  value       = aws_db_instance.source.endpoint
}

output "source_db_address" {
  description = "Source RDS instance address (hostname)"
  value       = aws_db_instance.source.address
}

output "source_db_port" {
  description = "Source RDS instance port"
  value       = aws_db_instance.source.port
}

output "source_db_name" {
  description = "Source database name"
  value       = aws_db_instance.source.db_name
}

# Target RDS Outputs
output "target_db_endpoint" {
  description = "Target RDS instance endpoint"
  value       = aws_db_instance.target.endpoint
}

output "target_db_address" {
  description = "Target RDS instance address (hostname)"
  value       = aws_db_instance.target.address
}

output "target_db_port" {
  description = "Target RDS instance port"
  value       = aws_db_instance.target.port
}

output "target_db_name" {
  description = "Target database name"
  value       = aws_db_instance.target.db_name
}

# DMS Outputs
output "dms_replication_instance_arn" {
  description = "DMS replication instance ARN"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "dms_replication_instance_id" {
  description = "DMS replication instance ID"
  value       = aws_dms_replication_instance.main.replication_instance_id
}

output "dms_source_endpoint_arn" {
  description = "DMS source endpoint ARN"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "dms_target_endpoint_arn" {
  description = "DMS target endpoint ARN"
  value       = aws_dms_endpoint.target.endpoint_arn
}

output "dms_replication_task_arn" {
  description = "DMS replication task ARN"
  value       = aws_dms_replication_task.main.replication_task_arn
}

output "dms_replication_task_id" {
  description = "DMS replication task ID"
  value       = aws_dms_replication_task.main.replication_task_id
}

# Connection Information
output "connection_info" {
  description = "Database connection information"
  value = {
    source = {
      host     = aws_db_instance.source.address
      port     = aws_db_instance.source.port
      database = var.db_name
      username = var.db_username
    }
    target = {
      host     = aws_db_instance.target.address
      port     = aws_db_instance.target.port
      database = var.db_name
      username = var.db_username
    }
  }
  sensitive = true
}

# Helpful Commands Output
output "helpful_commands" {
  description = "Useful commands for managing the migration"
  value = <<-EOT
    
    # Start the DMS migration task:
    aws dms start-replication-task --replication-task-arn ${aws_dms_replication_task.main.replication_task_arn} --start-replication-task-type start-replication
    
    # Check migration task status:
    aws dms describe-replication-tasks --filters Name=replication-task-arn,Values=${aws_dms_replication_task.main.replication_task_arn}
    
    # Test source endpoint connection:
    aws dms test-connection --replication-instance-arn ${aws_dms_replication_instance.main.replication_instance_arn} --endpoint-arn ${aws_dms_endpoint.source.endpoint_arn}
    
    # Test target endpoint connection:
    aws dms test-connection --replication-instance-arn ${aws_dms_replication_instance.main.replication_instance_arn} --endpoint-arn ${aws_dms_endpoint.target.endpoint_arn}
    
  EOT
}
