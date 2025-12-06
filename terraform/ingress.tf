# AWS Certificate Manager certificate
resource "aws_acm_certificate" "main" {
  count = var.create_dns_zone ? 1 : 0

  domain_name       = var.dns_zone_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.dns_zone_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags, {
    Name = "${local.name}-certificate"
  })
}

# DNS validation
resource "aws_route53_record" "cert_validation" {
  for_each = var.create_dns_zone ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main[0].zone_id
}

# Wait for certificate validation
# Potential issues here waiting for ACM Certificate to be validated
resource "aws_acm_certificate_validation" "main" {
  count = var.create_dns_zone ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.16.0"

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.aws_load_balancer_controller_irsa.arn
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = module.vpc.vpc_id
    }
  ]

  depends_on = [
    module.eks,
    module.aws_load_balancer_controller_irsa
  ]
}

# External-DNS (only if DNS zone is created)
resource "helm_release" "external_dns" {
  count = var.create_dns_zone ? 1 : 0

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.19.0"

  set = [
    {
      name  = "provider"
      value = "aws"
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "external-dns"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.external_dns_irsa[0].arn
    },
    {
      name  = "domainFilters[0]"
      value = var.dns_zone_name
    },
    {
      name  = "txtOwnerId"
      value = module.eks.cluster_name
    },
    {
      name  = "policy"
      value = "sync"
    }
  ]

  depends_on = [
    module.eks,
    module.external_dns_irsa,
    aws_route53_zone.main
  ]
}