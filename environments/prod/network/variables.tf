variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "env_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "nat_gateway_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
