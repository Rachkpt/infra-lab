output "wg_gateway_public_ip" {
  description = "IP publique fixe (Elastic IP) de wg-gateway"
  value       = aws_eip.wg_gateway.public_ip
}

output "monitoring_public_ip" {
  value = aws_instance.monitoring.public_ip
}

output "runner_ci_public_ip" {
  value = aws_instance.runner_ci.public_ip
}
