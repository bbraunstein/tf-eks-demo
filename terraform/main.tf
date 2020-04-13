provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {}
variable "ec2_key_pair" {}
variable "sg_id" {}

data "aws_subnet_ids" "subnet_ids" {
  vpc_id = var.vpc_id
}

data "aws_subnet" "subnet" {
  for_each = data.aws_subnet_ids.subnet_ids.ids
  value    = each.value
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "EksCluster"
  role_arn = aws_iam_role.eks_iam_role.arn
  vpc_config {
    subnet_ids = [for s in data.aws_subnet.subnet : s.id]
  }

  # Ensure that IAM Role permissions are created before and after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infra such as Security Groups
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}

resource "aws_iam_role" "eks_iam_role" {
  name               = "eks-cluster-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_iam_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_iam_role.name
}

## Node Groups section
resource "aws_iam_role" "node_group_iam_role" {
  name = "eks-node-group-iam-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.node_group_iam_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = aws_iam_role.node_group_iam_role.name
}

resource "aws_iam_role_policy_attachment" "eks_ecs_registry_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = aws_iam_role.node_group_iam_role.name
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn = aws_iam_role.node_group_iam_role.arn
  subnet_ids = [ for s in data.aws_subnet.subnets : s.id ]
  scaling_config {
    desired_size = 2
    max_size = 2
    min_size = 2
  }
  remote_access {
    ec2_ssh_key = var.ec2_key_pair
    source_security_group_ids = [var.sg_id]
  }

  # Ensure that IAM Role permissiongs are created before and deleted after EKS Node Group handling
  # Otherwise EKS will not be able to properly delete EC2 instances and ENIs
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecs_registry_readonly,
  ]
}

## Outputs Section ##
output "endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "kubeconfig-ca-data" {
  value = aws_eks_cluster.eks_cluster.certificate_authority.0.data
}
