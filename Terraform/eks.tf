module "eks" {
  source                                 = "terraform-aws-modules/eks/aws"
  version                                = "20.30.0" # Published November 27, 2024
  create                                 = true
  cluster_name                           = local.cluster_name
  cluster_version                        = "1.31"
  authentication_mode                    = "API"
  cluster_endpoint_private_access        = true # Indicates whether or not the Amazon EKS private API server endpoint is enabled
  cluster_endpoint_public_access         = true # Indicates whether or not the Amazon EKS public API server endpoint is enabled
  cloudwatch_log_group_retention_in_days = 30
  create_kms_key                         = var.create_kms_key
  enable_irsa                            = true # Determines whether to create an OpenID Connect Provider for EKS to enable IRSA

  /* -----------------------------------------------------------------------------------
  Install default unmanaged add-ons, such as aws-cni, kube-proxy, and CoreDNS during cluster creation. 
  If false, you must manually install desired add-ons (via the console, especially the Amazon VPC CNI add-on), 
  else even though your worker nodes will join the cluster, it will fail to be ready, showing the error:
  "container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized"
  
  Changing this value will force a new cluster to be created.
  ----------------------------------------------------------------------------------- */
  bootstrap_self_managed_addons = true

  cluster_encryption_config = {}

  cluster_addons = {
    # coredns is deployed as a deployment.
    coredns = {
      # most_recent = true
      addon_version = "v1.11.3-eksbuild.2"
    }
    # kube-proxy pod (that is deployed as a daemonset) shares the same IPv4 address as the node it's on.
    kube-proxy = {
      addon_version = "v1.31.2-eksbuild.3"
    }
    # Network interface will show all IPs used in the subnet
    # VPC-CNI creates elastic network interfaces and attaches them to your Amazon EC2 nodes. The add-on also assigns a private IPv4 or IPv6 address from your VPC to each Pod and service.
    vpc-cni = {
      addon_version            = "v1.19.0-eksbuild.1" # major-version.minor-version.patch-version-eksbuild.build-number.
      service_account_role_arn = aws_iam_role.vpc_cni_iam_role.arn
      configuration_values = jsonencode(
        {
          enableNetworkPolicy = "true"
          env = {
            # https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
            # kubectl get ds aws-node -n kube-system -o yaml
            WARM_IP_TARGET    = "3"
            MINIMUM_IP_TARGET = "3"
            # ENABLE_NETWORK_POLICY_CONTROLLER = "true"
            # NETWORK_POLICY_ENFORCING_MODE = "strict" # strict | standard
          }
        }
      )
    }
    /*
    Creates a deployment (ebs-csi-controller) and daemonset (ebs-csi-node)
    */
    aws-ebs-csi-driver = {
      addon_version            = "v1.37.0-eksbuild.1"
      service_account_role_arn = aws_iam_role.amazon_EBS_CSI_iam_role.arn
    }
    # eks-pod-identity-agent = {}
  }

  vpc_id = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  /* -----------------------------------------------------------------------------------
  A list of subnet IDs where the nodes/node groups will be provisioned.
  If control_plane_subnet_ids is not provided, the EKS cluster control plane (ENIs) will be provisioned in these subnets
  ----------------------------------------------------------------------------------- */
  subnet_ids = var.create_vpc ? (var.create_eks_worker_nodes_in_private_subnet ? module.vpc[0].list_of_private_subnet_ids : module.vpc[0].list_of_public_subnet_ids) : var.list_of_subnet_ids

  /* -----------------------------------------------------------------------------------
  A list of subnet IDs where the EKS Managed ENIs will be provisioned.
  Used for expanding the pool of subnets used by nodes/node groups without replacing the EKS control plane
  ----------------------------------------------------------------------------------- */
  control_plane_subnet_ids = var.create_vpc ? (var.create_eks_worker_nodes_in_private_subnet ? module.vpc[0].list_of_private_subnet_ids : module.vpc[0].list_of_public_subnet_ids) : var.list_of_subnet_ids

  # EKS Managed Node Group(s)
  /*
  Amazon EC2 T3 instances are the next generation burstable general-purpose instance 
  type that provide a baseline level of CPU performance with the ability to burst
  CPU usage at any time for as long as required. 
  T3 instances offer a balance of compute, memory, and network resources and are 
  designed for applications with moderate CPU usage that experience temporary spikes in use.
  */
  eks_managed_node_group_defaults = {
    instance_types = ["t3.medium", "t3.large"]
    # t3.medium: 2 vCPU, 4GiB
    # t3.large: 2 vCPU, 8GiB
    # t3.xlarge: 4 vCPU, 16GiB

    # iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"]
  }

  eks_managed_node_groups = {
    node_group_1 = {
      ### Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      # ami_type       = "AL2023_x86_64_STANDARD"
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.large", "t3.medium"]
      capacity_type  = "SPOT"
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  ### https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  # cluster_enabled_log_types = [
  #   "audit",
  #   "api",
  #   "authenticator",
  #   "controllerManager",
  #   "scheduler"
  # ]

  tags = local.default_tags
}

resource "aws_security_group_rule" "node_port" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
}

output "eks_managed_node_groups_autoscaling_group_names" {
  value = module.eks.eks_managed_node_groups_autoscaling_group_names
}

output "cluster_primary_security_group_id" {
  value = module.eks.cluster_primary_security_group_id
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of OIDC provider"
  value       = module.eks.oidc_provider_arn
}