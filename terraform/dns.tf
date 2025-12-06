# Optional Route53 Hosted Zone for Kubernetes Ingress
# checkov:skip=CKV2_AWS_39: "Not a requirmement for logging at this time"
resource "aws_route53_zone" "main" {
  count = var.create_dns_zone ? 1 : 0

  name = var.dns_zone_name

  tags = merge(local.tags, {
    Name = "${local.name}-dns-zone"
  })
}

# KMS Key for DNSSEC
resource "aws_kms_key" "dnssec" {
  count = var.create_dns_zone ? 1 : 0

  provider = aws.us-east-1

  description              = "KMS key for DNSSEC signing for ${var.dns_zone_name}"
  deletion_window_in_days  = 7
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P256"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Route 53 DNSSEC Service"
        Effect = "Allow"
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:route53:::hostedzone/*"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.name}-dnssec-key"
  })
}

resource "aws_kms_alias" "dnssec" {
  count = var.create_dns_zone ? 1 : 0

  provider = aws.us-east-1

  name          = "alias/${local.name}-dnssec"
  target_key_id = aws_kms_key.dnssec[0].key_id
}

resource "aws_route53_key_signing_key" "main" {
  count = var.create_dns_zone ? 1 : 0

  provider = aws.us-east-1

  hosted_zone_id             = aws_route53_zone.main[0].zone_id
  name                       = "${local.name}-ksk"
  key_management_service_arn = aws_kms_key.dnssec[0].arn
}

resource "aws_route53_hosted_zone_dnssec" "main" {
  count = var.create_dns_zone ? 1 : 0

  hosted_zone_id = aws_route53_zone.main[0].zone_id

  depends_on = [
    aws_route53_key_signing_key.main
  ]
}

resource "aws_route53domains_registered_domain" "main" {
  count = var.create_dns_zone && var.is_aws_registered_domain ? 1 : 0

  provider = aws.us-east-1

  domain_name = var.dns_zone_name

  name_server {
    name = aws_route53_zone.main[0].name_servers[0]
  }
  name_server {
    name = aws_route53_zone.main[0].name_servers[1]
  }
  name_server {
    name = aws_route53_zone.main[0].name_servers[2]
  }
  name_server {
    name = aws_route53_zone.main[0].name_servers[3]
  }
}
