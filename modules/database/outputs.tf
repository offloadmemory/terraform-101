output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_sg_id" {
  value = tolist(aws_db_instance.this.vpc_security_group_ids)[0]
}
