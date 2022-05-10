terraform {
  required_version = ">= 1.0.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.6.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }
  }

  backend "local" {
    path = "local_tf_state/terraform-main.tfstate"
  }
}

data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_blueprints.eks_cluster_id
}

provider "aws" {
  region = var.region
  alias  = "default"
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}

locals {
  tenant          = var.tenant      # AWS account name or unique id for tenant
  environment     = var.environment # Environment area eg., preprod or prod
  zone            = var.zone        # Environment with in one sub_tenant or business unit
  cluster_version = var.cluster_version

  vpc_cidr     = "10.0.0.0/16"
  vpc_name     = join("-", [local.tenant, local.environment, local.zone, "vpc"])
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
  cluster_name = join("-", [local.tenant, local.environment, local.zone, "eks"])

  terraform_version = "Terraform v1.0.1"
}

module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v3.2.0"

  name = local.vpc_name
  cidr = local.vpc_cidr
  azs  = local.azs

  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}
#---------------------------------------------------------------
# Example to consume eks_blueprints module
#---------------------------------------------------------------
module "eks_blueprints" {
  source = "../../../../terraform-aws-eks-blueprints/"

  tenant            = local.tenant
  environment       = local.environment
  zone              = local.zone
  terraform_version = local.terraform_version

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = module.aws_vpc.vpc_id
  private_subnet_ids = module.aws_vpc.private_subnets

  # EKS CONTROL PLANE VARIABLES
  cluster_version = local.cluster_version

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_4 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      min_size        = "2"
      subnet_ids      = module.aws_vpc.private_subnets
     bottlerocket     = true
    }
    mg_bottlerocket_x86 = {
      node_group_name = "managed-bottlerocket"
      instance_types  = ["m5.large"]
      min_size        = "2"
      subnet_ids      = module.aws_vpc.private_subnets
      ami_type        = "BOTTLEROCKET_x86_64"
      release_version = ""
      k8s_labels ={
        Environment = "preprod"
        Zone        = "dev"
        env         = "BOTTLEROCKET_x86"
      }
      
    }
    mg_bottlerocket_arm = {
      node_group_name = "managed-bottlerocket-arm"
      instance_types  = ["m6g.large"]
      min_size        = "2"
      subnet_ids      = module.aws_vpc.private_subnets
      ami_type        = "BOTTLEROCKET_ARM_64"
      release_version = ""
      k8s_labels ={
        Environment = "preprod"
        Zone        = "dev"
        env         = "BOTTLEROCKET_ARM"
      }
      
    }

  }

  fargate_profiles = {
    default = {
      fargate_profile_name = "default"
      fargate_profile_namespaces = [
        {namespace = "default"}
        {namespace = "nginx-fargate"}
        ]

      subnet_ids = module.aws_vpc.private_subnets

      additional_tags = {
        ExtraTag = "Fargate"
      }
    },
  }
}

module "eks_blueprints_kubernetes_addons" {
  source = "../../../../terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id               = module.eks_blueprints.eks_cluster_id
  eks_worker_security_group_id = module.eks_blueprints.worker_node_security_group_id

  # EKS Managed Add-ons
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  # K8s Add-ons
  enable_aws_efs_csi_driver           = true
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_cluster_autoscaler           = true
  enable_vpa                          = true
  enable_prometheus                   = true
  enable_aws_for_fluentbit            = true
  enable_aws_cloudwatch_metrics       = true
  enable_argocd                       = true
  enable_argo_rollouts                = true

  depends_on = [module.eks_blueprints.managed_node_groups]
}

