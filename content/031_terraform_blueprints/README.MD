## Prerequisites
### Install Terraform
```
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform
```

### Install kubectl
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Clone Workshop contnet from github
`git clone https://github.com/walkermiller/eks-workshop`

### Clone EKS Terraform Blueprints from github
`git clone https://github.com/aws-ia/terraform-aws-eks-blueprints.git`

## Deploy EKS

`terraform apply`