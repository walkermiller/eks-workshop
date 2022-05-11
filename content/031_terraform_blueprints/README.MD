## Prerequisites
### Install Terraform
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform
```

### Install kubectl
```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.6/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Install Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | VERIFY_CHECKSUM=false bash
```

### Clone Workshop contnet from github
```sh
git clone https://github.com/walkermiller/eks-workshop
```

### Clone EKS Terraform Blueprints from github
```sh
git clone https://github.com/aws-ia/terraform-aws-eks-blueprints.git
```

## Deploy EKS

**Initialize the Terraform project**
```bash
cd eks-workshop/content/031_terraform_blueprints/launcheks.files
terraform init
```

**Allow Terraform to plan the deployment**
```bash
terrafrom plan
```

**Apply the Terraform**
```bash
terraform apply
```

This will deploy the EKS Cluster with both a managed node group of on-demand instances:
```yaml
managed_node_groups = {
    mg_4 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      min_size        = "2"
      subnet_ids      = module.aws_vpc.private_subnets
     bottlerocket     = true
    }
```
And, a fargate instance profile for the default namespace:
```yaml
fargate_profiles = {
    default = {
      fargate_profile_name = "default"
      fargate_profile_namespaces = [{
        namespace = "default"
        k8s_labels = {
          Environment = "preprod"
          Zone        = "dev"
          env         = "fargate"
        }
      }]

      subnet_ids = module.aws_vpc.private_subnets

      additional_tags = {
        ExtraTag = "Fargate"
      }
    },
  }
}
```
Additionally, we will be installing the following AddOns:
```
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
```
### Update Kubeconfig (If any of the 'tenent','zone', or 'environment' values were changed, the name below will need to be updated to reflect)
```bash
aws eks update-kubeconfig --region us-east-2 --name aws-preprod-qa-eks
```

### Check Node status
```bash
kubectl get nodes -o wide
```
Since nothing has been deployed to the Fargate namespaces, you will not see any Fargate nodes yet. 

## Deploy to the cluster


### Deploy to Managed Nodegroup
**Create namespace**
```
kubectl create namespace nginx-managed-ondemand
```
**Deploy NGINX Pod**
```
kubectl apply -f nginx.yaml --namespace nginx-managed-ondemand
```

**Check to see status**
```
kubctl get po -n nginx-managed-ondemand
```

### Deploy to Fargate
**Create Fargate Namespace**
```
kubectl create namespace nginx-fargate
```
**Deploy NGINX Pod**
```
kubectl apply -f nginx.yaml --namespace nginx-fargate
```
**Check Status**
```
kubctl get po -n nginx-fargate
```

### Deploy to x86 Bottlerocket managed nodegroup
**Create namespace**
```
kubectl create namespace nginx-x86-bottlerocket
```
**Deploy NGINX Pod**
```
kubectl apply -f nginx.yaml --namespace nginx-x86-bottlerocket
```
**Check Status**
```
kubctl get po -n nginx-x86-bottlerocket
```

### Deploy to ARM Bottlerocket nodegroup
**Create namespace**
```
kubectl create namespace nginx-arm-bottlerocket
```
**Deploy NGINX Pod**
```
kubectl apply -f nginx.yaml --namespace nginx-arm-bottlerocket
```
**Check Status**
```
kubctl get po -n nginx-arm-bottlerocket
```

We've now deployed our NGINX pod to Managed nodegroups running on Amazon Linux 2, Bottlerocket on x86, Bottlerocket on ARM, and Fargate using Terraform to create our cluster and it's compute, and using kubectl to deploy our nginx container. Next, we want to use Helm to perform a deployment. 

## Install via helm 

[Follow the instructions in the Workshop](https://www.eksworkshop.com/beginner/060_helm/helm_intro/)

## Install via ArgoCD

[Follow the instructions in the Workshop](https://www.eksworkshop.com/intermediate/290_argocd/configure/)


