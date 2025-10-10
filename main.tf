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

  provisioner "file" {
    source      = "${path.module}/helm/"
    destination = "/home/ubuntu/helm/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/qiross.pem")
      host        = self.public_ip
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/full-setup.log) 2>&1
              
              echo "🚀 Starting complete setup..."
              
              # Update system
              apt update && apt upgrade -y
              apt install -y curl wget git unzip
              
              # Install AWS CLI v2
              echo "📦 Installing AWS CLI..."
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install
              
              # Install Docker
              echo "🐳 Installing Docker..."
              apt install -y docker.io
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ubuntu
              
              # Install kubectl
              echo "⚙️ Installing kubectl..."
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              
              # Install Minikube
              echo "🎯 Installing Minikube..."
              curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
              install minikube-linux-amd64 /usr/local/bin/minikube
              
              # Install Helm
              echo "📦 Installing Helm..."
              curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
              
              # Start Minikube with ingress
              echo "🚀 Starting Minikube..."
              sudo -u ubuntu minikube start --driver=docker --memory=4g --cpus=2
              sudo -u ubuntu minikube addons enable ingress
              
              # Configure kubectl for ubuntu user
              mkdir -p /home/ubuntu/.kube
              cp /root/.kube/config /home/ubuntu/.kube/
              chown -R ubuntu:ubuntu /home/ubuntu/.kube
              
              # Login to ECR and pull image
              echo "🔐 Logging into ECR..."
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 492211462076.dkr.ecr.us-east-1.amazonaws.com
              
              echo "📦 Pulling image from ECR..."
              docker pull 492211462076.dkr.ecr.us-east-1.amazonaws.com/hextrix:1
              
              # Load image to Minikube
              echo "🎯 Loading image to Minikube..."
              sudo -u ubuntu minikube image load 492211462076.dkr.ecr.us-east-1.amazonaws.com/hextrix:1
              
              echo "🚀 Deploying with Helm..."
              cd /home/ubuntu && sudo -u ubuntu helm upgrade --install hextris ./helm/ --namespace hextris --create-namespace

              sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

              sudo -u ubuntu nohup kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 --address 0.0.0.0 &
              
            EOF

  tags = {
    Name = "minikube-hextris"
  }

  depends_on = [aws_iam_role_policy_attachment.ecr_power_user]
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/qiross.pem ubuntu@${aws_instance.minikube.public_ip}"
}

output "app_url" {
  value = "http://${aws_instance.minikube.public_ip}"
}