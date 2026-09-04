// Self-managed node group: an ASG built from a launch template outside the EKS Managed Node
// Group API (eksctl's "unmanaged" nodegroup shape). No aws_eks_node_group resource fits this —
// there is no cluster-side node group object, just an ASG whose launch template already carries
// the bootstrap script that joins it to the cluster.
//
// desired_size is left to the autoscaler for the same reason as modules/eks-node-group.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name                = var.node_group_name
  vpc_zone_identifier = var.subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_size
  max_size         = var.max_size

  launch_template {
    name    = var.launch_template.name
    version = var.launch_template.version
  }

  dynamic "tag" {
    for_each = merge(
      {
        "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      },
      var.tags,
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

output "node_group_name" {
  value = aws_autoscaling_group.this.name
}
