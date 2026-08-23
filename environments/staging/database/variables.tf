variable "region" {
  description = "AWS region where the database is deployed"
  type        = string
}

variable "profile" {
  description = "Named AWS CLI profile used to authenticate to the environment account"
  type        = string
}

variable "env_name" {
  description = "Environment name (dev, staging, prod); used as a resource prefix"
  type        = string
}

variable "db_name" {
  description = "Name of the database created inside the RDS instance"
  type        = string
  default     = "appdb"
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t4g.micro)"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage size in GB"
  type        = number
  default     = 20
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 1
}

variable "multi_az" {
  description = "Whether to deploy the database across multiple availability zones"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the database"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when the database is destroyed"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to database resources"
  type        = map(string)
  default     = {}
}
