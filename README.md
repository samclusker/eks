# AWS EKS Cluster with Karpenter

Terraform IaC to deploy an AWS EKS cluster with Karpenter autoscaling and ingress support.

## Features

- ✅ **Multi-AZ VPC**: Public, private, and intra subnets with NAT gateway and VPC Flow Logs
- ✅ **EKS Cluster**: Managed Kubernetes cluster with public and private endpoints
- ✅ **Karpenter Autoscaling**: Node autoscaler with automatic provisioning (Linux/amd64, Nitro instances)
- ✅ **EKS Addons**:
  - VPC CNI
  - CoreDNS
  - kube-proxy
  - EBS CSI Driver
  - Snapshot Controller
  - Pod Identity Agent
  - Secrets Manager
  - metrics-server
  - kube-state-metrics
- ✅ **Ingress Support**: AWS Load Balancer Controller (ALB/NLB) with optional Route53 and ACM certificate
- ✅ **DNS Management**: Optional External-DNS for automatic Route53 record management
- ✅ **Security**: IRSA, security groups, VPC Flow Logs, Bottlerocket AMI

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.13.0
- kubectl installed
- IAM permissions for EKS, VPC, IAM, CloudWatch

## Quick Start

### 1. Configure Variables

Edit `terraform/terraform.prod.tfvars` (or create environment-specific file):

```hcl
region      = "eu-north-1"
environment = "production"  # dev, staging, or production

kubernetes_version = "1.34"

instance_types       = ["m5.large"]
primary_min_size     = 2
primary_max_size     = 3
primary_desired_size = 2

create_dns_zone = false # Optional
dns_zone_name = "<dns_zone>" # Optional
is_aws_registered_domain = false # Optional
```

### 2. Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review changes
terraform plan -var-file=terraform.prod.tfvars

# Deploy (takes ~15-20 minutes)
terraform apply -var-file=terraform.prod.tfvars
```

### 3. Configure kubectl

Inspect outputs given by Terraform on successful apply:

```bash
cluster_certificate_authority_data = "..."
cluster_endpoint = "..."
cluster_name = "eks-task-production"
cluster_security_group_id = "..."
karpenter_queue_name = "..."
kubectl_config_command = "aws eks update-kubeconfig --region eu-north-1 --name eks-task-production" # <--
node_security_group_id = "..."
oidc_provider_arn = "..."
region = "eu-north-1"
vpc_id = "..."

# Configure kubectl
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
```

## Validation

### 1. Verify Cluster Status

```bash
# Check cluster is accessible
kubectl cluster-info

# Verify nodes
kubectl get nodes -o wide
```

### 2. Verify Addons

```bash
# Check all addons are healthy
kubectl get pods -n kube-system

# Verify specific addons
kubectl get pods -n kube-system | grep -E "ebs-csi|coredns|vpc-cni|kube-proxy|pod-identity|aws-load-balancer|external-dns"

# Expected output should show:
# - ebs-csi-controller-* (2/2 ready)
# - coredns-* (2/2 ready)
# - aws-node-* (DaemonSet, 1 per node)
# - kube-proxy-* (DaemonSet, 1 per node)
# - eks-pod-identity-agent-* (DaemonSet, 1 per node)
# - aws-load-balancer-controller-* (1/1 ready)
# - external-dns-* (1/1 ready, if DNS zone created)

# Verify snapshot addon
kubectl get pods -n aws-secrets-manager

# Expected output should show:

# aws-secrets-store-csi-driver-provider-*
# secrets-store-csi-driver-*
```

### 3. Verify Karpenter

```bash
# Check Karpenter controller is running
kubectl get pods -n kube-system | grep karpenter

# Expected: karpenter-* pod should be Running

# Check Karpenter logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=50

# Verify Karpenter resources
kubectl get nodepool default
kubectl get ec2nodeclass default

# Check NodePool status (should be Ready)
kubectl get nodepool default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: "True"

# Check EC2NodeClass status
kubectl get ec2nodeclass default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: "True"
```

### 4. Test Karpenter Node Provisioning

```bash
# Create a test deployment that requires more resources than available
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-karpenter
spec:
  replicas: 5
  selector:
    matchLabels:
      app: test-karpenter
  template:
    metadata:
      labels:
        app: test-karpenter
    spec:
      containers:
      - name: test
        image: nginx
        resources:
          requests:
            cpu: 2
            memory: 4Gi
EOF

# Watch Karpenter provision nodes
watch kubectl get nodes

# After a few minutes, you should see new nodes being provisioned
# Clean up test deployment
kubectl delete deployment test-karpenter
```

### 5. Verify Security Groups

```bash
# Check security groups are tagged for Karpenter discovery
aws ec2 describe-security-groups \
  --filters "Name=tag:karpenter.sh/discovery,Values=eks-task-production" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table

# Should show at least the node security group
```

### 6. Verify Ingress Controllers

```bash
# Check AWS Load Balancer Controller is running
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check External-DNS (if DNS zone created)
kubectl get pods -n kube-system | grep external-dns

# Verify ACM certificate (if DNS zone created)
terraform output acm_certificate_arn
```

### 7. Verify Network Configuration

```bash
# Check subnets are properly tagged
aws ec2 describe-subnets \
  --filters "Name=tag:karpenter.sh/discovery,Values=eks-task-production" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Should show 3 private subnets (one per AZ)
```

## Configuration

### Key Variables

| Variable                   | Description                                                                            | Default                     |
|----------------------------|----------------------------------------------------------------------------------------|-----------------------------|
|                   `region` |                                                                             AWS region |                `eu-north-1` |
|              `environment` |                                                   Environment (dev/staging/production) |                `production` |
|       `kubernetes_version` |                                                                     Kubernetes version |                      `1.34` |
|           `instance_types` |                                                      Managed node group instance types | `["t3.medium", "t3.large"]` |
|         `primary_min_size` |                                                         Minimum nodes in managed group |                         `1` |
|         `primary_max_size` |                                                         Maximum nodes in managed group |                         `2` |
|     `primary_desired_size` |                                                         Desired nodes in managed group |                         `1` |
|          `create_dns_zone` |                         Creates Route53 hosted zone, ACM certificate, and External-DNS |                     `false` |
| `is_aws_registered_domain` |                                  Confirm whether your domain is registered in Route 53 |                     `false` |
|            `dns_zone_name` | Domain name for Route53 zone (e.g., example.com). Required if `create_dns_zone = true` |                        `""` |
|

### Cluster Naming

Cluster name is automatically generated as: `eks-task-${environment}`

Examples:
- Production: `eks-task-production`
- Staging: `eks-task-staging`
- Dev: `eks-task-dev`

### Karpenter NodePool Configuration

Default NodePool: Linux/amd64, Nitro instances (c/m/r families), 4-32 CPU cores, Bottlerocket AMI, 30-day expiration, WhenEmpty consolidation.

### Ingress Configuration

When `create_dns_zone = true`, the following are provisioned:
- **Route53 Hosted Zone**: DNS zone for your domain
- **ACM Certificate**: Wildcard certificate (`*.example.com` and `example.com`) with automatic DNS validation
- **External-DNS**: Automatically manages Route53 records based on Kubernetes Ingress resources
- **AWS Load Balancer Controller**: Always deployed, manages ALB/NLB for Kubernetes Ingress

Use the certificate ARN in your Ingress annotations:
```yaml
annotations:
  alb.ingress.kubernetes.io/certificate-arn: <output from terraform output acm_certificate_arn>
```

## Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (AZ-1, AZ-2, AZ-3)
│   └── NAT Gateway
├── Private Subnets (AZ-1, AZ-2, AZ-3)
│   └── EKS Worker Nodes (Karpenter-managed)
│   └── Managed Node Group (Karpenter controller)
└── Intra Subnets (AZ-1, AZ-2, AZ-3)
    └── EKS Control Plane
```

## Troubleshooting

### Karpenter Not Provisioning Nodes

```bash
# Check Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter

# Verify NodePool is Ready
kubectl get nodepool default -o yaml | grep -A 5 "type: Ready"

# Verify EC2NodeClass can find resources
kubectl get ec2nodeclass default -o yaml | grep -A 10 "status:"

# Check for security group issues
kubectl get ec2nodeclass default -o jsonpath='{.status.conditions[?(@.type=="SecurityGroupsReady")]}'
```

### Addons Not Healthy

```bash
# Check addon status
aws eks describe-addon \
  --cluster-name eks-task-production \
  --addon-name aws-ebs-csi-driver \
  --query 'addon.status'

# Check pod events
kubectl describe pod -n kube-system <pod-name>

# Check if pods are unscheduled
kubectl get pods -n kube-system -o wide | grep -v Running
```

### Nodes Not Joining

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name eks-task-production \
  --nodegroup-name <nodegroup-name>

# Check CloudWatch logs
aws logs tail /aws/eks/eks-task-production/cluster --follow
```

## Cleanup

```bash
cd terraform
terraform destroy -var-file=terraform.prod.tfvars
```

**Warning**: This deletes the entire EKS cluster and all associated resources.

## Outputs

Key outputs available via `terraform output`:
- `cluster_name`: EKS cluster name
- `cluster_endpoint`: EKS API endpoint
- `kubectl_config_command`: Command to configure kubectl
- `acm_certificate_arn`: ACM certificate ARN (if DNS zone created)

## Modules Used

- [terraform-aws-modules/vpc/aws](https://github.com/terraform-aws-modules/terraform-aws-vpc) (~> 6.0)
- [terraform-aws-modules/eks/aws](https://github.com/terraform-aws-modules/terraform-aws-eks) (~> 21.9.0)
- [terraform-aws-modules/eks/aws//modules/karpenter](https://github.com/terraform-aws-modules/terraform-aws-eks/tree/v21.9.0/modules/karpenter)
- [terraform-aws-modules/iam/aws](https://github.com/terraform-aws-modules/terraform-aws-iam) (~> 5.28)

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Karpenter Documentation](https://karpenter.sh/)
- [Terraform AWS EKS Module](https://github.com/terraform-aws-modules/terraform-aws-eks)
