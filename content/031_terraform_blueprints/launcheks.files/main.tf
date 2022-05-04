locals {
  tenant      = var.tenant
  environment = var.environment
  zone        = var.zone
  region      = "us-east-2"

  terraform_version = "Terraform v1.0.1"

  vpc_id             = data.terraform_remote_state.vpc_s3_backend.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc_s3_backend.outputs.private_subnets
}


odule "eks_blueprints" {
  source = "../../.."

  tenant            = local.tenant
  environment       = local.environment
  zone              = local.zone
  terraform_version = local.terraform_version

  # EKS Cluster VPC and Subnets
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids

  # EKS CONTROL PLANE VARIABLES
  cluster_version = "1.21"

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_4 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.xlarge"]
      subnet_ids      = local.private_subnet_ids
    }
  }

  fargate_profiles = {
    default = {
    fargate_profile_name = "default"
    fargate_profile_namespaces = [
        {
        namespace = "default"
        k8s_labels = {
            Environment = "preprod"
            Zone        = "dev"
            env         = "fargate"
        }
    }]
    subnet_ids = local.private_subnets
    additional_tags = {
        ExtraTag = "Fargate"
    }
    }
  }
}

module "eks_blueprints_kubernetes_addons" {
  source = "../../../modules/kubernetes-addons"

  eks_cluster_id               = module.eks_blueprints.eks_cluster_id
  eks_worker_security_group_id = module.eks_blueprints.worker_node_security_group_id

  # EKS Managed Add-ons
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  #K8s Add-ons
  enable_aws_efs_csi_driver           = true
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_cluster_autoscaler           = true
  enable_vpa                          = true
  enable_prometheus                   = true
  enable_ingress_nginx                = true
  enable_aws_for_fluentbit            = true
  enable_aws_cloudwatch_metrics       = true
  enable_argocd                       = true
  enable_fargate_fluentbit            = true
  enable_argo_rollouts                = true

  depends_on = [module.eks_blueprints.managed_node_groups]
}
