terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  disk_size      = var.disk_size

  // AMI type and launch template are mutually constrained: a CUSTOM ami_type requires a template,
  // and a template that specifies its own image requires CUSTOM. Left to the caller rather than
  // inferred, because guessing wrong here replaces every node in the group.
  ami_type = var.ami_type

  scaling_config {
    min_size     = var.min_size
    desired_size = var.desired_size
    max_size     = var.max_size
  }

  dynamic "launch_template" {
    for_each = var.launch_template == null ? [] : [var.launch_template]

    content {
      name    = launch_template.value.name
      version = launch_template.value.version
    }
  }

  labels = var.labels

  dynamic "taint" {
    for_each = var.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = var.tags

  lifecycle {
    // desired_size is the autoscaler's to move once the group exists; re-asserting it on every
    // apply would fight the autoscaler and mask what Sedai actually changed.
    ignore_changes = [scaling_config[0].desired_size]
  }
}

output "node_group_name" {
  value = aws_eks_node_group.this.node_group_name
}
