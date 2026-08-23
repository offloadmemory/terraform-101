output "db_endpoint" {
  description = "Hostname endpoint of the RDS database"
  value       = aws_db_instance.this.address
  sensitive   = true
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.this.db_name
  sensitive   = true
}

output "db_port" {
  description = "Port on which the database accepts connections"
  value       = aws_db_instance.this.port
  sensitive   = true
}

output "db_sg_id" {
  description = "ID of the security group attached to the database"
  value       = tolist(aws_db_instance.this.vpc_security_group_ids)[0]
}
