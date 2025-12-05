# Cluster Information
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "region" {
  description = "AWS region where the cluster is deployed"
  value       = var.region
}

# Network Information
output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for the cluster"
  value       = module.eks.oidc_provider_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# kubectl Configuration
output "kubectl_config_command" {
  description = "Command to configure kubectl to connect to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

# Karpenter Information
output "karpenter_queue_name" {
  description = "Name of the SQS queue used by Karpenter for spot interruption handling"
  value       = module.karpenter.queue_name
}

# Cert ARN for ingress annotation population
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the domain"
  value       = var.create_dns_zone ? aws_acm_certificate_validation.main[0].certificate_arn : null
}
