output "staging_ip" {
  description = "IP Publico da maquina de Staging"
  value = aws_instance.staging.public_ip
}

output "production_ip" {
  description = "IP Publico da maquina de Producao"
  value = aws_instance.production.public_ip
}