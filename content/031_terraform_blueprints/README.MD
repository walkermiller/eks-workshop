## Prerequisites
### Create an s3 bucket for our state files
```
aws s3 mb s3://terraform-state-us-east-2-$(aws sts get-caller-identity --query "Account" --output text)
```

### Create a bin directory
mkdir bin
### Install Terraform
```bash
curl -LO https://releases.hashicorp.com/terraform/1.1.9/terraform_1.1.9_linux_amd64.zip
unzip terraform_1.1.9_linux_amd64.zip -d ~/bin
rm terraform_1.1.9_linux_amd64.zip
```

### Install kubectl
```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.6/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl ~/bin/
```

### Install Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | HELM_INSTALL_DIR=~/bin VERIFY_CHECKSUM=false bash
```

### Install argocd cli
```bash
sudo curl --silent --location -o ~/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.0.4/argocd-linux-amd64
sudo chmod +x ~/bin/argocd

```

### Clone Workshop contnet from github
```sh
git clone https://github.com/walkermiller/eks-workshop
```

### Clone EKS Terraform Blueprints from github
```sh
git clone https://github.com/aws-ia/terraform-aws-eks-blueprints.git
```

### Create a Symobolic link for all the Terrafrom provider details. 
```bash 
mkdir /tmp/.terraform
ln -s /tmp/.terraform /home/cloudshell-user/eks-workshop/content/031_terraform_blueprints/launcheks.files/.terraform
```

### Move to the working directory
```bash
cd eks-workshop/content/031_terraform_blueprints/launcheks.files
```
### Copy reconnect script
This script should be used if your cloud shell needs to be restarted for any reason. Copying it to the bin directory allows us to call it whenever we need to. 
```
cp eks-workshop/content/031_terraform_blueprints/launcheks.files/reconnect ~/bin/
```

## Deploy EKS

**Initialize the Terraform project**
Note: If you restart your Cloud Shell environment, this will need to be rerun, as the /tmp directory does not persist. 
```bash
terraform init -backend-config="bucket=terraform-state-us-east-2-$(aws sts get-caller-identity --query "Account" --output text)"
```

**Allow Terraform to plan the deployment**
```bash
terraform plan
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
Additionally, we have installed the following Add-Ons:
```
  # EKS Managed Add-ons
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true

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

## Enable Fargate
### Create the Fargate profile
Uncomment the following lines from main.tf
```yaml
fargate_profiles = {
    default = {
      fargate_profile_name = "default"
      fargate_profile_namespaces = [{
        namespace = "default"
        k8s_labels = {}
      }]

      subnet_ids = module.aws_vpc.private_subnets

      additional_tags = {
        ExtraTag = "Fargate"
      }
    },
  }
}
```
Run Terraform plan and apply
```bash
terraform plan
terraform apply
```


### Update Kubeconfig (If any of the 'tenent','zone', or 'environment' values were changed, the name below will need to be updated to reflect)
```bash
aws eks update-kubeconfig --region us-east-2 --name aws-preprod-dev-eks
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
kubectl create namespace nginx-managed
```
**Deploy NGINX Pod**
```
kubectl apply -f nginx.yaml --namespace nginx-managed
```

**Check to see status**
```
kubctl get po -n nginx-managed
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
kubectl get po -n nginx-fargate
```

## Installs via Helm 

[Follow the instructions in the Workshop](https://www.eksworkshop.com/beginner/060_helm/helm_intro/)

## Installs via ArgoCD

[Follow the instructions in the Workshop](https://www.eksworkshop.com/intermediate/290_argocd/configure/)
The following commands are modified to reflect this deployment. 
Enable an external Load Balancer
```bash
kubectl patch svc argo-cd-argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```
Login to argocd cli
```bash
export ARGOCD_SERVER=`kubectl get svc argo-cd-argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'`
export ARGO_PWD=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
argocd login $ARGOCD_SERVER --username admin --password $ARGO_PWD --insecure
~~~

## Using EFS
[Follow the instructions in the Workshop](https://www.eksworkshop.com/beginner/190_efs/launching-efs/)

- Use the correct cluster name.
- You do not have to redelpoy the EFS CSI Driver