// EKS managed node group. Kept alongside eks-self-managed-node-group because the cluster runs
// both: several MNGs carry a `node.sedai.io/replaced-by` taint pointing at a Karpenter pool, so the
// two are mid-migration and a change to one is often paired with a change to the other.
//
// This module's inputs are still plain HCL variables — every value flowing in is decoded from the
// YAML heredoc in the calling root via yamldecode(), not typed here as YAML. See
// eks-node-groups/<account>/main.tf.

variable "node_group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "node_role_arn" {
  type = string
}

variable "instance_types" {
  description = "EKS_NODE_GROUP_INSTANCE_TYPE. A list, but MNGs in practice pin one per group."
  type        = list(string)
}

variable "min_size" {
  description = "EKS_NODE_GROUP_MIN_NODES."
  type        = number
  default     = 0
}

variable "desired_size" {
  description = "EKS_NODE_GROUP_INSTANCE_COUNT. Drifts under autoscaling — Sedai reads it, the IaC declares the starting point."
  type        = number
  default     = 0
}

variable "max_size" {
  description = "EKS_NODE_GROUP_MAX_NODES."
  type        = number
  default     = 1
}

variable "disk_size" {
  description = "EKS_NODE_GROUP_DISK_SIZE in GiB. null when a launch template supplies the volume."
  type        = number
  default     = null
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "ami_type" {
  description = "AL2023_x86_64_STANDARD, AL2023_ARM_64_STANDARD, or CUSTOM with a launch template."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "launch_template" {
  description = <<-EOT
    EKS_NODE_GROUP_LAUNCH_TEMPLATE_NAME / _VERSION. null means the group uses the EKS-generated
    template, which is the majority of this cluster.
  EOT
  type = object({
    name    = string
    version = string
  })
  default = null
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "taints" {
  type = list(object({
    key    = string
    value  = optional(string)
    effect = string
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
