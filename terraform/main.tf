# terraform/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "qiross"
}

data "aws_key_pair" "qiross" {
  key_name = "qiross"
}

resource "aws_vpc" "minikube_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "minikube-vpc"
  }
}

resource "aws_subnet" "minikube_subnet" {
  vpc_id                  = aws_vpc.minikube_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "minikube-subnet"
  }
}

resource "aws_internet_gateway" "minikube_igw" {
  vpc_id = aws_vpc.minikube_vpc.id

  tags = {
    Name = "minikube-igw"
  }
}

resource "aws_route_table" "minikube_rt" {
  vpc_id = aws_vpc.minikube_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minikube_igw.id
  }

  tags = {
    Name = "minikube-rt"
  }
}

resource "aws_route_table_association" "minikube_rta" {
  subnet_id      = aws_subnet.minikube_subnet.id
  route_table_id = aws_route_table.minikube_rt.id
}

resource "aws_security_group" "minikube" {
  name        = "minikube-sg"
  description = "Security group for Minikube"
  vpc_id      = aws_vpc.minikube_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "minikube-sg"
  }
}

resource "aws_iam_role" "minikube_role" {
  name = "minikube-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_power_user" {
  role       = aws_iam_role.minikube_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_instance_profile" "minikube_profile" {
  name = "minikube-profile"
  role = aws_iam_role.minikube_role.name
}

resource "aws_instance" "minikube" {
  ami                    = "ami-0360c520857e3138f" # Ubuntu 24.04
  instance_type          = "t3.large"
  key_name               = data.aws_key_pair.qiross.key_name
  iam_instance_profile   = aws_iam_instance_profile.minikube_profile.name
  vpc_security_group_ids = [aws_security_group.minikube.id]
  subnet_id              = aws_subnet.minikube_subnet.id
  
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "minikube-hextris"
  }
}

# Outputs
output "public_ip" {
  value = aws_instance.minikube.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/qiross.pem ubuntu@${aws_instance.minikube.public_ip}"
}

output "app_url" {
  value = "http://${aws_instance.minikube.public_ip}"
}