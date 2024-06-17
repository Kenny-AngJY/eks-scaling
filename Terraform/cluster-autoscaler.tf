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

/*
If you want to allow all service accounts within a namespace to use the role,
use "StringLike" instead of "StringEquals"
*/
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
          "StringLike" : {
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:*:*",
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "clusterautoscaler-iam-role" {
  role       = aws_iam_role.clusterautoscaler-iam-role.name
  policy_arn = aws_iam_policy.clusterautoscaler_iam_policy.arn
}