# EKS managed node groups for sedai-peteam-managed-us-east-1 (account 7sbi1xj2).
#
# One root for all of them, unlike a per-pool Karpenter layout: MNGs are provisioned together with
# the cluster's networking and share subnets and a node role, so splitting them per-directory would
# duplicate that wiring without buying isolation.
#
# Every group here carries a `node.sedai.io/replaced-by` taint naming its Karpenter successor — the
# migration is in progress, and the taint is what keeps new pods off the old group.
#
# The whole config below is YAML, not tfvars: this repo declares node pools the way a Kubernetes
# manifest would, and Terraform only supplies the heredoc + yamldecode() plumbing to turn that YAML
# into real aws_eks_node_group / aws_autoscaling_group resources. Edit the YAML block, not HCL.

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
    clusterName: sedai-peteam-managed-us-east-1

    nodeRoleArn: "arn:aws:iam::022347029601:role/KarpenterNode-sedai-peteam-managed-us-east-1-lgcraxfw"

    subnetIds:
      - subnet-085081a3a4440cf20
      - subnet-026ae041974b04efd
      - subnet-032a2f4c4034a5e90
      - subnet-05774b43415e0e54f

    # The one eksctl "unmanaged" nodegroup on this cluster — see modules/eks-self-managed-node-group.
    selfManagedNodeGroup:
      nodeGroupName: eksctl-sedai-peteam-managed-us-east-1-nodegroup-sedai-self-managed-test-v1-NodeGroup-McjLxAOLlbS2
      minSize: 0
      desiredSize: 1
      maxSize: 10
      launchTemplate:
        name: eksctl-sedai-peteam-managed-us-east-1-nodegroup-sedai-self-managed-test-v1
        version: "1"

    nodeGroups:
      amd-extra-20260217063515828500000003:
        instanceTypes: [m6a.large, m6a.xlarge]
        minSize: 0
        desiredSize: 2
        maxSize: 10
        launchTemplate: {name: amd-extra-20260217060306746700000009, version: "2"}
        labels: {arch: amd64, group: amd-extra}
        taints:
          - {key: node.sedai.io/replaced-by, value: amd-extra-20260217063515828500000003-karpenter, effect: NO_SCHEDULE}

      # Being migrated to the arm-extra-sedai-test-karpenter pool; the taint is what drains it.
      arm-extra-sedai-test:
        instanceTypes: [t4g.large, t4g.xlarge]
        minSize: 0
        desiredSize: 0
        maxSize: 6
        amiType: AL2023_ARM_64_STANDARD
        launchTemplate: {name: arm-extra-20260217060306746500000007, version: "1"}
        labels: {arch: arm64, group: arm-extra}
        taints:
          - {key: node.sedai.io/replaced-by, value: arm-extra-sedai-test-karpenter, effect: NO_SCHEDULE}

      # Graviton default pool. Widest size range in the cluster, scales to 10.
      default-20260217063515828500000001:
        instanceTypes: [t4g.small, t4g.medium, t4g.large, t4g.xlarge]
        minSize: 0
        desiredSize: 2
        maxSize: 10
        amiType: AL2023_ARM_64_STANDARD
        launchTemplate: {name: default-2026012110281453120000000c, version: "2"}

      # CUSTOM amiType: the launch template carries its own image, so EKS must not pick one.
      flavor-final-boss-v5:
        instanceTypes: [m5.xlarge, m5.2xlarge]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        amiType: CUSTOM
        launchTemplate: {name: lt-flavor-final-boss-v5, version: "1"}
        labels: {Environment: mng-production}
        taints:
          - {key: node.sedai.io/replaced-by, value: flavor-final-boss-v5-karpenter, effect: NO_SCHEDULE}

      karp-flavor11-vanilla-1775025856:
        instanceTypes: [t3.medium]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        diskSize: 20
        taints:
          - {key: node.sedai.io/replaced-by, value: karp-flavor11-vanilla-1775025856-karpenter, effect: NO_SCHEDULE}

      karp-flavor12-api-overrides-1775038100:
        instanceTypes: [t3.large]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        diskSize: 57
        labels: {sedai.io/cost-center: finance, test-flavor: "12"}
        taints:
          - {key: experimental, value: "true", effect: NO_SCHEDULE}
          - {key: node.sedai.io/replaced-by, value: karp-flavor12-api-overrides-1775038100-karpenter, effect: NO_SCHEDULE}

      karp-flavor13-brutal-1775039317:
        instanceTypes: []
        minSize: 0
        desiredSize: 0
        maxSize: 1
        launchTemplate: {name: brutal-lt-1775039317, version: "1"}

      karp-flavor18-eni-1775460268:
        instanceTypes: [t3.medium]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        launchTemplate: {name: net-eni-lt-1775460268, version: "1"}

      # Exercises a non-zero minSize floor (min == desired == max == 1).
      karp-flavor18-root-1775460185:
        instanceTypes: [t3.medium]
        minSize: 1
        desiredSize: 1
        maxSize: 1
        launchTemplate: {name: net-root-lt-1775460185, version: "1"}

      karp-flavor19-divergent-1775462608:
        instanceTypes: [t3.medium]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        diskSize: 20
        taints:
          - {key: node.sedai.io/replaced-by, value: karp-flavor19-divergent-1775462608-karpenter, effect: NO_SCHEDULE}

      # Named for an HPC placement-group launch template.
      karp-flavor20-hpc-1775463816:
        instanceTypes: [m5.large]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        launchTemplate: {name: hpc-placement-lt-1775463816, version: "1"}

      karpenter-system-1776065719936:
        instanceTypes: [m5.large]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        diskSize: 20

      karpenter-system-1776143289982:
        instanceTypes: [m5.large]
        minSize: 1
        desiredSize: 1
        maxSize: 4
        diskSize: 20
        labels: {nodepool: karpenter}
        taints:
          - {key: karpenter.sh/dedicated, value: "true", effect: NO_SCHEDULE}

      # Third karpenter-system replica in this account.
      karpenter-system-1776159700058:
        instanceTypes: [m5.large]
        minSize: 1
        desiredSize: 1
        maxSize: 4
        diskSize: 20
        labels: {nodepool: karpenter}
        taints:
          - {key: karpenter.sh/dedicated, value: "true", effect: NO_SCHEDULE}

      mng-simple-v1-1775449388:
        instanceTypes: [t3.large]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        launchTemplate: {name: lt-simple-v1-1775449388, version: "1"}
        labels: {workload: canary-logger}
        taints:
          - {key: node.sedai.io/replaced-by, value: mng-simple-v1-1775449388-karpenter, effect: NO_SCHEDULE}

      # Mid-migration MNG without a replaced-by taint yet.
      mng-test-migration-v1:
        instanceTypes: [t3.medium]
        minSize: 0
        desiredSize: 1
        maxSize: 1
        diskSize: 20
        labels: {workload: test-migration}

      mng-workload-v1-1775739939:
        instanceTypes: [t3.medium]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        launchTemplate: {name: lt-managed-node-v1-1775739939, version: "1"}
        labels: {workload: canary-logger}
        taints:
          - {key: node.sedai.io/replaced-by, value: mng-workload-v1-1775739939-karpenter, effect: NO_SCHEDULE}

      # Exercises Karpenter-style compaction behavior on an MNG.
      sedai-compaction-test:
        instanceTypes: [t3.medium]
        minSize: 0
        desiredSize: 2
        maxSize: 4
        diskSize: 20
        labels: {sedai.io/compaction-test: "true"}

      sedai-expander-spot-a:
        instanceTypes: [m5.large, m5a.large, m5d.large, m4.large]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        diskSize: 20
        capacityType: SPOT
        labels: {sedai-expander-test: sedai-expander-spot-a}
        taints:
          - {key: node.sedai.io/replaced-by, value: sedai-expander-spot-a-karpenter, effect: NO_SCHEDULE}

      # SPOT with a four-type spread so the ASG has alternatives when one pool is exhausted.
      sedai-expander-spot-b:
        instanceTypes: [c5.large, c5a.large, c5d.large, c4.large]
        minSize: 3
        desiredSize: 3
        maxSize: 3
        diskSize: 20
        capacityType: SPOT
        labels: {sedai-expander-test: sedai-expander-spot-b}

      sedai-minsize-test:
        instanceTypes: [t3.small]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        diskSize: 20
        taints:
          - {key: dedicated, value: sedaitest, effect: NO_SCHEDULE}
          - {key: node.sedai.io/replaced-by, value: sedai-minsize-test-karpenter, effect: NO_SCHEDULE}

      # Exercises Sedai's smart-scheduler label.
      smart-scheduler-test:
        instanceTypes: [c5.xlarge]
        minSize: 0
        desiredSize: 1
        maxSize: 1
        diskSize: 20
        labels: {sedai.io/smart-scheduler-pool: test, sedai.io/smart-scheduler-test: "true"}
        taints:
          - {key: sedai.io/smart-scheduler-test, value: "true", effect: NO_SCHEDULE}

      # Plain smoke-test group, no taints or custom labels.
      test-node-grp-simple:
        instanceTypes: [t3.medium]
        minSize: 0
        desiredSize: 0
        maxSize: 1
        launchTemplate: {name: lt-simple-test-1776159078, version: "1"}
        labels: {pool: test, workload: canary-logger}
        taints:
          - {key: node.sedai.io/replaced-by, value: test-node-grp-simple-karpenter, effect: NO_SCHEDULE}
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
    Environment = "dev"
  }
}

module "self_managed_node_group" {
  source = "../../modules/eks-self-managed-node-group"

  node_group_name = local.config.selfManagedNodeGroup.nodeGroupName
  cluster_name    = local.config.clusterName
  subnet_ids      = local.config.subnetIds

  min_size        = local.config.selfManagedNodeGroup.minSize
  desired_size    = local.config.selfManagedNodeGroup.desiredSize
  max_size        = local.config.selfManagedNodeGroup.maxSize
  launch_template = local.config.selfManagedNodeGroup.launchTemplate

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

output "node_group_names" {
  value = [for m in module.node_group : m.node_group_name]
}

output "self_managed_node_group_name" {
  value = module.self_managed_node_group.node_group_name
}
