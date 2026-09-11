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
  default = 2
}

variable "max_size" {
  type    = number
  default = 3
}

variable "launch_template" {
  description = "The ASG's launch template already carries the AMI, instance type and bootstrap script."
  type = object({
    name    = string
    version = string
  })
}

variable "instance_types" {
  description = <<-EOT
    EKS_NODE_GROUP_INSTANCE_TYPE. Optional override of the launch template's instance type(s),
    applied via the ASG's mixed_instances_policy. null means use whatever the launch template
    itself specifies.
  EOT
  type        = list(string)
  default     = ["t3.medium"]
}

variable "disk_size" {
  description = <<-EOT
    EKS_NODE_GROUP_DISK_SIZE in GiB. KNOWN GAP: aws_autoscaling_group cannot override a launch
    template's block device mapping, so this value is not applied to the resource below — it is
    tracked here for parity with modules/eks-node-group until this module owns its own
    aws_launch_template.
  EOT
  type        = number
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
