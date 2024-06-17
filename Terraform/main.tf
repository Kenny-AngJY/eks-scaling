locals {
  name         = "k8s-monitor-os"
  cluster_name = format("%s-%s", local.name, "eks-cluster")

  default_tags = {
    stack       = local.name
    terraform   = true
    description = "Test scaling and monitoring on AWS EKS"
  }
}

module "vpc" {
  count          = var.create_vpc ? 1 : 0
  source         = "./modules/vpc"
  stack_name     = local.name
  vpc_cidr_block = "10.9.0.0/16"

  list_of_azs        = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  list_of_cidr_range = ["10.9.101.0/24", "10.9.102.0/24", "10.9.103.0/24"]

  default_tags = local.default_tags
  cluster_name = local.cluster_name
}