variable "node_group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "min_size" {
  type    = number
  default = 0
}

variable "desired_size" {
  type    = number
  default = 0
}

variable "max_size" {
  type    = number
  default = 1
}

variable "launch_template" {
  description = "The ASG's launch template already carries the AMI, instance type and bootstrap script."
  type = object({
    name    = string
    version = string
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}
