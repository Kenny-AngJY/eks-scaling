/* -----------------------------------------------------------------------------------
Cluster AutoScaler
----------------------------------------------------------------------------------- */
resource "aws_iam_role" "clusterautoscaler-iam-role" {
  name        = "clusterautoscaler-iam-role"
  description = "IAM role for clusterautoscaler"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${module.eks.oidc_provider_arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringLike" : { # If you want to allow all service accounts within a namespace to use the role, use "StringLike" instead of "StringEquals"
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:*:*",
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

}

# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#full-cluster-autoscaler-features-policy-recommended
resource "aws_iam_policy" "clusterautoscaler_iam_policy" {
  name        = "ClusterAutoScaler-IAM-Policy"
  path        = "/"
  description = "Full Cluster Autoscaler Features Policy (Recommended)"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ],
        "Resource" : ["*"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        "Resource" : ["*"],
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled" : "true",
            "autoscaling:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" : "owned"
          }
        }
      }
    ]
  })
}

# resource "aws_iam_role_policy_attachment" "clusterautoscaler_iam_policy_to_node_group" {
#   role       = module.eks.eks_managed_node_groups["node_group_1"]["iam_role_name"]
#   policy_arn = aws_iam_policy.clusterautoscaler_iam_policy.arn
# }

resource "aws_iam_role_policy_attachment" "clusterautoscaler-iam-role" {
  role       = aws_iam_role.clusterautoscaler-iam-role.name
  policy_arn = aws_iam_policy.clusterautoscaler_iam_policy.arn
}

/* -----------------------------------------------------------------------------------
EKS Amazon EBS CSI add-on
----------------------------------------------------------------------------------- */
resource "aws_iam_role" "amazon_EBS_CSI_iam_role" {
  name        = "amazon-ebs-csi-irsa"
  description = "IAM role for Amazon EBS CSI driver add-on"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${module.eks.oidc_provider_arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringLike" : {
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa",
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "amazon_EBS_CSI_iam_role" {
  role       = aws_iam_role.amazon_EBS_CSI_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

/* -----------------------------------------------------------------------------------
VPC CNI
----------------------------------------------------------------------------------- */
resource "aws_iam_role" "vpc_cni_iam_role" {
  name        = "vpc-cni-irsa"
  description = "IAM role for VPC-CNI add-on"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${module.eks.oidc_provider_arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringLike" : {
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:kube-system:aws-node",
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "vpc_cni_iam_role" {
  role       = aws_iam_role.vpc_cni_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}