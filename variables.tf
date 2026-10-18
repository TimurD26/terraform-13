variable "region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "project_tag" {
  description = "Project tag for resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "blue_weight" {
  description = "Traffic weight for Blue environment"
  type        = number
}

variable "green_weight" {
  description = "Traffic weight for Green environment"
  type        = number
}