variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-north-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging or production"
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.34"
}

variable "instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "primary_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

variable "primary_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 2
}

variable "primary_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 1
}

variable "create_dns_zone" {
  description = "Whether to create a Route53 hosted zone for Kubernetes ingress"
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Domain name for the Route53 hosted zone (e.g., example.com). Required if create_dns_zone is true."
  type        = string
  default     = ""

  validation {
    condition     = var.create_dns_zone ? var.dns_zone_name != "" : true
    error_message = "dns_zone_name must be provided when create_dns_zone is true"
  }
}
