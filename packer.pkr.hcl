packer {
  required_version = ">= 1.9.0"
  
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3"
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region to build AMI"
  type        = string
  default     = "us-east-1"
}

variable "docker_image" {
  description = "Docker image to bake into AMI"
  type        = string
  # Default to httpd for testing, override with your image
  default     = "httpd:latest"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Data source for latest Amazon Linux 2023 AMI
data "amazon-ami" "amazon_linux_2023" {
  filters = {
    name                = "al2023-ami-*-x86_64"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.aws_region
}

# Locals for computed values
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name  = "fastapi-golden-ami-${var.environment}-${local.timestamp}"
}

# Source configuration
source "amazon-ebs" "fastapi" {
  region        = var.aws_region
  source_ami    = data.amazon-ami.amazon_linux_2023.id
  instance_type = "t2.micro"
  ssh_username  = "ec2-user"
  
  # AMI configuration
  ami_name        = local.ami_name
  ami_description = "Golden AMI with Docker and FastAPI application"
  
  # Tags for the AMI
  tags = {
    Name        = local.ami_name
    Environment = var.environment
    Application = "fastapi"
    BuildDate   = local.timestamp
    ManagedBy   = "Packer"
    DockerImage = var.docker_image
  }
  
  # Tags for the temporary instance during build
  run_tags = {
    Name      = "packer-builder-fastapi"
    ManagedBy = "Packer"
    Temporary = "true"
  }
}

# Build configuration
build {
  sources = ["source.amazon-ebs.fastapi"]
  
  # Set environment variable for Docker image
  provisioner "shell" {
    environment_vars = [
      "DOCKER_IMAGE=${var.docker_image}"
    ]
    script = "scripts/setup.sh"
  }
  
  # Verify the setup
  provisioner "shell" {
    inline = [
      "echo 'Verifying Docker installation...'",
      "docker --version",
      "echo 'Verifying systemd service...'",
      "sudo systemctl status fastapi-app.service || true",
      "echo 'Setup verification complete!'"
    ]
  }
  
  # Output AMI details
  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
  }
}
