# Awesome EKS VPC

A VPC module that makes the right decisions, so you can focus on what matters.

## The Philosophy

We've built a lot of VPCs. We've seen what works and what doesn't. This module captures those lessons.

Instead of giving you 47 knobs to turn, we give you a VPC architecture that's proven in production. Three subnet tiers. Sensible sizes. Proper isolation. The kind of foundation you'd be proud to run your infrastructure on.

**Our beliefs:**

- Three subnet tiers cover 99% of use cases: public, private, and isolated
- Private subnets deserve the most IP space—that's where your pods live
- Databases belong in isolated subnets with zero internet access—security by design
- Great defaults mean you write less code and ship faster

## The Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                              VPC                                    │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    PUBLIC SUBNETS (/20)                      │   │
│  │           ALBs • NAT Gateways • Bastion Hosts               │   │
│  │                    4,096 IPs each                            │   │
│  │                         │                                    │   │
│  │                    Internet Gateway                          │   │
│  │                         ↕                                    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│                         NAT Gateway                                 │
│                              ↓                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   PRIVATE SUBNETS (/19)                      │   │
│  │          EKS Nodes • ECS Tasks • Application Pods           │   │
│  │                    8,192 IPs each                            │   │
│  │                                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│                         VPC Local                                   │
│                              ↓                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                  ISOLATED SUBNETS (/21)                      │   │
│  │              RDS • ElastiCache • Data Stores                │   │
│  │                    2,048 IPs each                            │   │
│  │                                                              │   │
│  │                  🔒 NO INTERNET ACCESS                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "vpc" {
  source = "your-namespace/awesome-eks-vpc/aws"

  cidr_block = "10.0.0.0/16"
}
```

That's it. One variable. Production-ready VPC for EKS.

### Cost-Optimized NAT (Default)

```hcl
module "vpc" {
  source = "your-namespace/awesome-eks-vpc/aws"

  cidr_block       = "10.0.0.0/16"
  nat_gateway_mode = "regional"  # Default: single HA NAT Gateway
}
```

### Maximum Resilience NAT

```hcl
module "vpc" {
  source = "your-namespace/awesome-eks-vpc/aws"

  cidr_block       = "10.0.0.0/16"
  nat_gateway_mode = "per-az"  # One NAT Gateway per AZ
}
```

## How Subnets Get Created

Here's the magic behind the scenes.

### The Allocation Strategy

We allocate subnets in a specific order to maximize contiguous IP space:

1. **Private subnets first** — `/19` (8,192 IPs each)
2. **Public subnets second** — `/20` (4,096 IPs each)  
3. **Isolated subnets last** — `/21` (2,048 IPs each)

Private subnets get allocated first because they're the largest and need the most room. This keeps your CIDR space clean and predictable.

### The Math

For a `10.0.0.0/16` VPC with 3 subnets of each type:

| Subnet Type | CIDR Size | IPs Each | Count | Total IPs | Example CIDRs                                     |
|-------------|-----------|----------|-------|-----------|---------------------------------------------------|
| Private     | /19       | 8,192    | 3     | 24,576    | `10.0.0.0/19`, `10.0.32.0/19`, `10.0.64.0/19`     |
| Public      | /20       | 4,096    | 3     | 12,288    | `10.0.96.0/20`, `10.0.112.0/20`, `10.0.128.0/20`  |
| Isolated    | /21       | 2,048    | 3     | 6,144     | `10.0.144.0/21`, `10.0.152.0/21`, `10.0.160.0/21` |

**Total: 42,992 IPs** out of 65,536 available. Plenty of room to grow.

### Automatic AZ Distribution

By default, subnets are distributed across all availability zones in your region. In `us-east-1` with 6 AZs, you get 6 of each subnet type—automatically spread for high availability.

Want a specific count? Just say so:

```hcl
module "vpc" {
  source = "your-namespace/awesome-eks-vpc/aws"

  cidr_block            = "10.0.0.0/16"
  public_subnet_count   = 3
  private_subnet_count  = 3
  isolated_subnet_count = 3
}
```

The minimum is 3 subnets of each type—enough for proper high availability and Kubernetes best practices.

### Built-in Capacity Validation

Request more than your CIDR can handle? The module catches it with a helpful error:

```
Subnet configuration exceeds VPC capacity!

VPC CIDR: 10.0.0.0/18 (16,384 IPs available)

Requested subnets:
  - 3 private (/19): 24,576 IPs
  - 3 public (/20): 12,288 IPs
  - 3 isolated (/21): 6,144 IPs

Total required: 42,992 IPs

Reduce subnet counts or use a larger VPC CIDR block.
```

No silent failures. No overlapping CIDRs. Clear guidance on how to fix it.

## The Three Tiers

### Public Subnets

**What goes here:** ALBs, NAT Gateways, Bastion hosts—anything that needs a public IP.

**Size:** `/20` (4,096 IPs each) — More than enough for load balancers and jump boxes.

**Routing:** Direct path to the Internet Gateway.

**EKS Ready:** Tagged with `kubernetes.io/role/elb = 1` for the AWS Load Balancer Controller.

### Private Subnets

**What goes here:** EKS nodes, ECS tasks, Lambda in VPC—your application workloads.

**Size:** `/19` (8,192 IPs each) — Sized for Kubernetes. A single node can run 58+ pods, each needing an IP. We give you room.

**Routing:** Outbound through NAT Gateway. Protected from direct internet access.

**EKS Ready:** Tagged with `kubernetes.io/role/internal-elb = 1` for internal load balancers.

### Isolated Subnets

**What goes here:** RDS, ElastiCache, DocumentDB—your data tier.

**Size:** `/21` (2,048 IPs each) — Right-sized for database deployments.

**Routing:** VPC local only. No route to NAT. No route to internet.

**Security:** Restrictive NACLs explicitly deny all traffic except VPC CIDR. Defense in depth.

**Why no internet?** Your database doesn't need to reach the outside world. Keeping it isolated reduces your attack surface and simplifies compliance. If you need external connectivity for your data tier, VPC endpoints are the way.

## NAT Gateway Modes

### Regional Mode (Default)

One NAT Gateway with AWS-managed regional high availability.

- **Cost:** ~$32/month + data transfer
- **Resilience:** AWS automatically handles failover across AZs
- **Best for:** Most workloads, cost-conscious teams, getting started

### Per-AZ Mode

One NAT Gateway in each availability zone.

- **Cost:** ~$32/month × number of AZs + data transfer
- **Resilience:** AZ-isolated, traffic stays within the AZ
- **Best for:** Large-scale production, strict latency requirements, regulated industries

```hcl
nat_gateway_mode = "per-az"
```

## Inputs

| Name                    | Description                              | Type     | Default       | Required |
|-------------------------|------------------------------------------|----------|---------------|:--------:|
| `cidr_block`            | CIDR block for the VPC                   | `string` | n/a           | **yes**  |
| `public_subnet_count`   | Number of public subnets (min 3)         | `number` | Number of AZs |    no    |
| `private_subnet_count`  | Number of private subnets (min 3)        | `number` | Number of AZs |    no    |
| `isolated_subnet_count` | Number of isolated subnets (min 3)       | `number` | Number of AZs |    no    |
| `nat_gateway_mode`      | NAT Gateway mode: `regional` or `per-az` | `string` | `"regional"`  |    no    |

## Outputs

### Core

| Name                      | Description                            |
|---------------------------|----------------------------------------|
| `vpc_id`                  | The VPC ID                             |
| `availability_zones_used` | List of AZs where subnets were created |

### Subnets

| Name                    | Description                                        |
|-------------------------|----------------------------------------------------|
| `public_subnet_ids`     | List of public subnet IDs                          |
| `public_subnet_cidrs`   | List of public subnet CIDR blocks                  |
| `private_subnet_ids`    | List of private subnet IDs                         |
| `private_subnet_cidrs`  | List of private subnet CIDR blocks                 |
| `isolated_subnet_ids`   | List of isolated subnet IDs                        |
| `isolated_subnet_cidrs` | List of isolated subnet CIDR blocks                |
| `subnet_summary`        | Object with count, size, and purpose for each tier |

### Gateways

| Name                     | Description                    |
|--------------------------|--------------------------------|
| `internet_gateway_id`    | Internet Gateway ID            |
| `nat_gateway_ids`        | List of NAT Gateway IDs        |
| `nat_gateway_public_ips` | List of NAT Gateway public IPs |
| `nat_gateway_mode`       | The NAT Gateway mode in use    |

### Route Tables

| Name                      | Description                             |
|---------------------------|-----------------------------------------|
| `public_route_table_id`   | Public route table ID                   |
| `private_route_table_ids` | List of private route table IDs         |
| `isolated_route_table_id` | Isolated route table ID                 |
| `routing_summary`         | Object describing routing configuration |

## Using with EKS

```hcl
module "vpc" {
  source = "your-namespace/awesome-eks-vpc/aws"
  
  cidr_block = "10.0.0.0/16"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-cluster"
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  control_plane_subnet_ids = module.vpc.private_subnet_ids
}
```

The subnets come pre-tagged for EKS. Just plug them in.

## Requirements

| Name      | Version |
|-----------|---------|
| terraform | ~> 1.14 |
| aws       | ~> 6.27 |

## FAQ

**Why is the minimum 3 subnets?**

Kubernetes works best with resources spread across multiple availability zones. Three AZs gives you proper high availability and is the standard for production EKS clusters. Starting with 3 means you won't have to refactor later.

**Why are isolated subnets so locked down?**

Defense in depth. Route tables prevent internet access, and NACLs enforce it at the network layer. For data stores, this is exactly what you want—maximum protection with minimal attack surface.

**Why can't I customize subnet sizes?**

These sizes come from real-world experience running EKS at scale. `/19` for private handles thousands of pods. `/20` for public covers any ALB deployment. `/21` for isolated is right-sized for databases. They work. If you have an unusual use case that truly needs different sizes, we'd love to hear about it—open an issue.

**What if I need VPC peering or Transit Gateway?**

This module gives you the foundation. Add peering, Transit Gateway attachments, or VPC endpoints on top. The outputs give you everything you need to extend the VPC.

---

Built with conviction. Designed for production.
