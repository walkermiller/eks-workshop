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

### Clone Workshop contnet from github
`git clone https://github.com/walkermiller/eks-workshop`

### Clone EKS Terraform Blueprints from github
`git clone https://github.com/aws-ia/terraform-aws-eks-blueprints.git`

## Deploy EKS

```bash
cd eks-workshop/content/031_terraform_blueprints/launcheks.files
terraform init
```
```bash
terrafrom plan
```
```bash
terraform apply
```
