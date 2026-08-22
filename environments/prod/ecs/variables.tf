variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "env_name" {
  type = string
}

variable "image" {
  type    = string
  default = "nginx:alpine"
}

variable "cpu" {
  type    = string
  default = "256"
}

variable "memory" {
  type    = string
  default = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
