output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "blue_target_group_arn" {
  description = "ARN of the Blue target group"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "ARN of the Green target group"
  value       = aws_lb_target_group.green.arn
}

output "blue_asg_name" {
  description = "Name of the Blue Auto Scaling Group"
  value       = aws_autoscaling_group.blue.name
}

output "green_asg_name" {
  description = "Name of the Green Auto Scaling Group"
  value       = aws_autoscaling_group.green.name
}