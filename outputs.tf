output "alb_dns_name" {
  description = "Public DNS of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.php_server.public_ip
}

output "waf_name" {
  description = "AWS WAF Web ACL name"
  value       = aws_wafv2_web_acl.app_waf.name
}

output "app_url" {
  description = "Application URL through ALB"
  value       = "http://${aws_lb.app_alb.dns_name}"
}