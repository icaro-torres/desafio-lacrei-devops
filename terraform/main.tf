terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  role = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "web_sg" {
  name = "${var.project_name}-sg-v2"
  description = "Security Group com HTTPS"

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }
  ingress {
    description = "HTTP (Redireciona para HTTPS)"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS (Seguro)"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_key_pair" "deployer" {
  key_name = "${var.project_name}-key-v2"
  public_key = file(var.ssh_public_key_path)
}

locals {
  user_data_script = <<-EOF
    #!/bin/bash
    
    # 1. Instalação Básica
    apt-get update
    apt-get install -y docker.io nginx openssl awscli
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu

    # 2. Gerar Certificado SSL Autoassinado (HTTPS)
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/nginx/ssl/selfsigned.key \
      -out /etc/nginx/ssl/selfsigned.crt \
      -subj "/C=BR/ST=SP/L=SaoPaulo/O=LacreiSaude/OU=DevOps/CN=localhost"

    # 3. Configurar Nginx (Proxy Reverso)
    # Ele recebe na 443 (HTTPS) e manda para a 3000 (App Node)
    cat <<EOT > /etc/nginx/sites-available/default
    server {
        listen 80;
        server_name _;
        return 301 https://\$host\$request_uri; # Força HTTPS
    }

    server {
        listen 443 ssl;
        server_name _;

        ssl_certificate /etc/nginx/ssl/selfsigned.crt;
        ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

        location / {
            proxy_pass http://localhost:3000; # Manda pro Docker
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
    EOT

    # 4. Reiniciar Nginx para aplicar
    systemctl restart nginx
  EOF
}

resource "aws_instance" "staging" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "${var.project_name}-staging"
    Environment = "Staging"
  }
  user_data = local.user_data_script
}

resource "aws_instance" "production" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "${var.project_name}-production"
    Environment = "Production"
  }
  user_data = local.user_data_script
}