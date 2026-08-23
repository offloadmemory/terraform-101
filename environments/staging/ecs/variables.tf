variable "region" {
  description = "AWS region where the ECS services are deployed"
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

variable "image" {
  description = "Container image to run in the Fargate service"
  type        = string
  default     = "nginx:alpine"
}

variable "cpu" {
  description = "CPU units allocated to the Fargate task"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Memory (MiB) allocated to the Fargate task"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Common tags applied to ECS resources"
  type        = map(string)
  default     = {}
}
