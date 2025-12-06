# AWS Configuration
region      = "eu-north-1"
environment = "staging"

# Cluster Configuration
kubernetes_version = "1.34"

# Node Group Configuration
instance_types       = ["t3.medium", "t3.large"]
primary_min_size     = 1
primary_max_size     = 2
primary_desired_size = 1
