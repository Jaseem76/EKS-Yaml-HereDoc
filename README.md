# EKS-Yaml-HereDoc

Terraform for the EKS node groups of `sedai-peteam-managed-us-east-1`, across three AWS accounts
(`7sbi1xj2`, `axeq1rsk`, `oz1o0mjk`) that each run a cluster of that name. This is a YAML replica of
[`nodepool-iac`](../nodepool-iac)'s `eks-node-groups/` — same 78 rows, same modules, same AWS
resources — with only Karpenter left out (EKS managed/self-managed node groups only, no
`NodePool`/`EC2NodeClass`).

## The YAML-via-heredoc approach

`aws_eks_node_group` and `aws_autoscaling_group` are real AWS APIs — they have to stay HCL resource
blocks, no config format changes that. What *does* change is everything above the resource: instead
of a `.tfvars` file, each account root (`eks-node-groups/<account>/main.tf`) declares its node
groups as a single YAML document inside a Terraform heredoc, decoded with `yamldecode()`:

```hcl
locals {
  config = yamldecode(<<-YAML
    clusterName: sedai-peteam-managed-us-east-1
    nodeGroups:
      my-pool:
        instanceTypes: [t3.medium]
        minSize: 0
        desiredSize: 1
        maxSize: 4
  YAML
  )
}

module "node_group" {
  source   = "../../modules/eks-node-group"
  for_each = local.config.nodeGroups
  # ...
}
```

There is no `.tfvars` file anywhere in this repo — the YAML block *is* the data layer, and it's the
only thing a PR should ever need to edit. The module and provider plumbing around it is fixed
scaffolding, same as `nodepool-iac`'s `main.tf` was around its `.tfvars`.

```
modules/
  eks-node-group/               aws_eks_node_group
  eks-self-managed-node-group/  aws_autoscaling_group for the one eksctl-created group
eks-node-groups/
  <account_id>/
    main.tf   for_each over that account's managed groups + its self-managed group,
              driven entirely by the YAML heredoc at the top of the file
```

**One root per account, not one for all three.** The three clusters share a name but not a VPC, IAM
role, or subnet layout, so a single `for_each` across accounts would need a second dimension of
keying for no benefit — each account's node groups only ever change together with that account's own
PR.

## Known gap: `axeq1rsk` and `oz1o0mjk` have no role/subnet data

Account `7sbi1xj2`'s `nodeRoleArn` and `subnetIds` came from the original export (the role ARN was
reconstructed from an ASG ARN in that data). The other two accounts carry neither field, so their
YAML has `nodeRoleArn: ""` and `subnetIds: []` with a `TODO` marking them. `terraform validate`
passes (the values are well-typed), but `plan`/`apply` will fail until those are filled in.

## Using it

```bash
cd eks-node-groups/7sbi1xj2 && terraform init && terraform apply
```

Validation needs no cluster and no credentials:

```bash
for d in eks-node-groups/*/; do
  (cd "$d" && terraform init -backend=false >/dev/null && terraform validate)
done
```

## Not included

- The cluster, VPC, subnets, IAM roles.
- Karpenter `NodePool`/`EC2NodeClass` resources — out of scope for this repo by request.
- A backend block. Add one per root before using this anywhere shared.
