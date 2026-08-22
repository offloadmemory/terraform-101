variable "bucket_name" {
  description = "Globally unique S3 bucket name for remote state"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
}

variable "region" {
  description = "AWS region for state infrastructure"
  type        = string
}

variable "tags" {
  description = "Common tags applied to state resources"
  type        = map(string)
  default     = {}
}
