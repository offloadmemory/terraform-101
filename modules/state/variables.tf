variable "bucket_name" {
  description = "Globally unique S3 bucket name for remote state"
  type        = string
}

variable "tags" {
  description = "Common tags applied to state resources"
  type        = map(string)
  default     = {}
}
