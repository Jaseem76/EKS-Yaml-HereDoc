# EKS managed node groups for sedai-labs-beta (account dzycsnra).
#
# Transcribed from edisondb.sedai_resources: 4 KUBERNETES_EKS_NODE_GROUP_WITH_LAUNCH_TEMPLATE rows
# (sedai-labs-beta-mng-1-rollback-v1, sedai-labs-beta-mng-2-rollback-v1, sedai-labs-beta-mng-2-rollback-v2,
# test) and 1 KUBERNETES_EKS_SELF_MANAGED_NODE_GROUP row (sedai-labs-beta-smng).
#
# The whole config below is YAML, not tfvars: this repo declares node pools the way a Kubernetes
# manifest would, and Terraform only supplies the heredoc + yamldecode() plumbing to turn that YAML
# into real aws_eks_node_group / aws_autoscaling_group resources. Edit the YAML block, not HCL.
#
# KNOWN GAP: the source rows carry no IAM node role or subnet IDs for this account/cluster (the
# only per-node data is instance shape, launch template and scaling config). nodeRoleArn/subnetIds
# below are placeholders — fill them in from the account before applying. `terraform validate`
# passes (well-typed empty values); `plan`/`apply` will fail until they're filled in.
#
# Labels in the source rows (kubernetes.io/*, eks.amazonaws.com/*, beta.kubernetes.io/*, ...) are
# all cluster/kubelet-injected at runtime, not something a caller declares via aws_eks_node_group's
# `labels` argument — so none of them are carried into the YAML below.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

locals {
  config = yamldecode(<<-YAML
    clusterName: sedai-labs-beta

    # TODO: fill in from the account before applying.
    nodeRoleArn: ""
    subnetIds: []

    # The one self-managed nodegroup on this cluster — see modules/eks-self-managed-node-group.
    # autoScalingConfig on the source row is min=0/desired=0/max=0 with autoScalerEnabled false.
    selfManagedNodeGroup:
      nodeGroupName: sedai-labs-beta-smng-0
      minSize: 2
      diskSize: 30
      launchTemplate:
        name: sedai-labs-beta-smng-2026052211254333540000000b
        version: "14"

    nodeGroups:
      # rollback_v1 label on the launch template: pinned to m7a.medium, min == desired == max == 2.
      sedai-labs-beta-mng-1-new:
        instanceTypes: ["m7a.medium"]
        minSize: 2
        desiredSize: 2
        maxSize: 2
        diskSize: 20
        launchTemplate: {name: sedai-labs-beta-mng-1-20260610105144400700000001, version: "12"}

      # Same launch template family as mng-1-rollback-v1 (name), two versions behind (v10 vs v12).
      # Tainted to route pods off this group toward mng-2-rollback-v2.
      sedai-labs-beta-mng-2-rollback-v1:
        instanceTypes: [t3.medium]
        minSize: 5
        desiredSize: 5
        maxSize: 5
        capacityType: ON_DEMAND
        amiType: AL2023_x86_64_STANDARD
        launchTemplate: {name: sedai-labs-beta-mng-1-20260610105144400700000001, version: "10"}
        taints:
          - key: node.sedai.io/replaced-by
            value: sedai-labs-beta-mng-2-rollback-v2
            effect: NO_SCHEDULE

      # Same launch template family as mng-1, one version behind, t3.medium instead of m7a.medium.
      sedai-labs-beta-mng-2-rollback-v2:
        instanceTypes: [t3.medium]
        minSize: 2
        desiredSize: 5
        maxSize: 5
        diskSize: 20
        launchTemplate: {name: sedai-labs-beta-mng-1-20260610105144400700000001, version: "11"}

      # CUSTOM amiType: the launch template ("brian-test") carries its own image (t2.xlarge nodes
      # observed live), so instanceTypes is empty and EKS must not pick one. min == desired == max
      # == 0 in the source row — currentNodeCount:1 is live drift the IaC does not chase.
      test:
        instanceTypes: []
        minSize: 0
        desiredSize: 0
        maxSize: 0
        amiType: CUSTOM
        launchTemplate: {name: brian-test, version: "5"}
  YAML
  )
}

module "node_group" {
  source = "../../modules/eks-node-group"

  for_each = local.config.nodeGroups

  node_group_name = each.key
  cluster_name    = local.config.clusterName
  node_role_arn   = local.config.nodeRoleArn
  subnet_ids      = local.config.subnetIds

  instance_types  = each.value.instanceTypes
  min_size        = each.value.minSize
  desired_size    = each.value.desiredSize
  max_size        = each.value.maxSize
  disk_size       = try(each.value.diskSize, null)
  capacity_type   = try(each.value.capacityType, "ON_DEMAND")
  ami_type        = try(each.value.amiType, "AL2023_x86_64_STANDARD")
  launch_template = try(each.value.launchTemplate, null)
  labels          = try(each.value.labels, {})
  taints          = try(each.value.taints, [])

  tags = {
    Terraform   = "true"
    Environment = "labs"
  }
}

module "self_managed_node_group" {
  source = "../../modules/eks-self-managed-node-group"

  node_group_name = local.config.selfManagedNodeGroup.nodeGroupName
  cluster_name    = local.config.clusterName
  subnet_ids      = local.config.subnetIds

  min_size        = local.config.selfManagedNodeGroup.minSize
  launch_template = local.config.selfManagedNodeGroup.launchTemplate
  disk_size       = try(local.config.selfManagedNodeGroup.diskSize, null)

  tags = {
    Terraform   = "true"
    Environment = "labs"
  }
}

output "node_group_names" {
  value = [for m in module.node_group : m.node_group_name]
}

output "self_managed_node_group_name" {
  value = module.self_managed_node_group.node_group_name
}
