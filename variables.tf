variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "phpcrudwaf"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
}



variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}
variable "github_repo_url" {
  description = "URL du dépôt GitHub"
  type        = string
  default     = "https://github.com/Mohamed-Hedi-Jemaa/Terraform-AWS.git"
}

variable "db_name" {
  description = "Nom de la base"
  type        = string
  default     = "blog"
}

variable "db_user" {
  description = "Utilisateur MySQL"
  type        = string
  default     = "bloguser"
}

variable "db_password" {
  description = "Mot de passe MySQL"
  type        = string
  sensitive   = true
}