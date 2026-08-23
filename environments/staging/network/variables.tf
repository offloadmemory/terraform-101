variable "region" {
  description = "AWS region where the environment resources are deployed"
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

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones to deploy the VPC subnets across"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per availability zone"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets, one per availability zone"
  type        = list(string)
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways to provision in the VPC"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Common tags applied to all network resources"
  type        = map(string)
  default     = {}
}
