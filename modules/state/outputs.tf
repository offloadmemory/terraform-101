output "bucket_name" {
  value = aws_s3_bucket.state.id
}

output "table_name" {
  value = aws_dynamodb_table.state_lock.name
}
