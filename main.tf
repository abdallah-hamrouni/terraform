terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------
# Default VPC and subnets
# -------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "all" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# -------------------------
# Amazon Linux 2 AMI
# -------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -------------------------
# Locals
# -------------------------
locals {
  supported_azs = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]

  supported_subnet_ids = [
    for s in data.aws_subnet.all : s.id
    if contains(local.supported_azs, s.availability_zone)
  ]

  alb_subnets = slice(local.supported_subnet_ids, 0, 2)
  ec2_subnet  = local.supported_subnet_ids[0]
}

# -------------------------
# Security Group for ALB
# -------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP from Internet"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# -------------------------
# Security Group for EC2
# -------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow HTTP from ALB and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# -------------------------
# EC2 instance
# -------------------------
resource "aws_instance" "php_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = local.ec2_subnet
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras enable php8.0
              yum clean metadata
              yum install -y httpd php php-cli php-mbstring php-json php-mysqlnd mariadb-server git

              systemctl enable httpd
              systemctl start httpd

              systemctl enable mariadb
              systemctl start mariadb

              # Création DB + utilisateur
              mysql -u root <<MYSQL_SCRIPT
              CREATE DATABASE IF NOT EXISTS ${var.db_name};
              DROP USER IF EXISTS '${var.db_user}'@'localhost';
              CREATE USER '${var.db_user}'@'localhost' IDENTIFIED BY '${var.db_password}';
              GRANT ALL PRIVILEGES ON ${var.db_name}.* TO '${var.db_user}'@'localhost';
              FLUSH PRIVILEGES;
              MYSQL_SCRIPT

              # Récupération du projet
              cd /tmp
              rm -rf Terraform-AWS
              git clone ${var.github_repo_url}

              # Déploiement des fichiers PHP
              rm -rf /var/www/html/*
              cp -r /tmp/Terraform-AWS/src/* /var/www/html/

              # Initialisation de la base depuis le SQL du projet
              mysql -u root < /tmp/Terraform-AWS/src/articles.sql

              # Remplacement des placeholders de db-config.php
              sed -i "s/##DB_HOST##/localhost/g" /var/www/html/db-config.php
              sed -i "s/##DB_USER##/${var.db_user}/g" /var/www/html/db-config.php
              sed -i "s/##DB_PASSWORD##/${var.db_password}/g" /var/www/html/db-config.php

              chown -R apache:apache /var/www/html
              chmod -R 755 /var/www/html
              systemctl restart httpd
              EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

# -------------------------
# Application Load Balancer
# -------------------------
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.alb_subnets

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/index.php"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

resource "aws_lb_target_group_attachment" "app_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.php_server.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# -------------------------
# AWS WAF
# -------------------------
resource "aws_wafv2_web_acl" "app_waf" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-waf"
  }
}

resource "aws_wafv2_web_acl_association" "alb_assoc" {
  resource_arn = aws_lb.app_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.app_waf.arn
}

