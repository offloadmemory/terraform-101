output "db_endpoint" {
  description = "Hostname endpoint of the RDS database"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "db_name" {
  description = "Name of the database"
  value       = module.database.db_name
  sensitive   = true
}

output "db_port" {
  description = "Port on which the database accepts connections"
  value       = module.database.db_port
  sensitive   = true
}
