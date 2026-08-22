variable "env" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "backup_retention_period" {
  description = "Backup retention in days"
  type        = number
  default     = 1
}

variable "multi_az" {
  description = "Deploy across multiple AZs"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Prevent accidental deletion"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (dev convenience)"
  type        = bool
  default     = true
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "db_sg_id" {
  description = "Security group id that allows 5432 ingress from ECS"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
