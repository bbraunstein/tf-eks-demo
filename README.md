# tf-eks-demo
Terraform script to boostrap AWS EKS infra and node groups

## Pre-requistes
This script is for personal use and not intended to be implemented in any Production capacity. The terraform template has three assumptions:
- VPC with Internet Access
  - Public subnets with Internet Gateway attached, or
  - Private subnets with NAT Gateway attached
- EC2 Keypair
  - Allows connection to EKS Nodes
- Security Group with at least port 22 access
  - Allows connection to EKS Nodes
  - Can be public (0.0.0.0/0) or restricted to a single home IP
  - Recommended that **All Traffic** enabled
