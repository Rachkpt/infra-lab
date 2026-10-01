variable "aws_region" {
  description = "Region AWS utilisee pour le lab"
  type        = string
  default     = "eu-west-3"
}

variable "my_ip" {
  description = "Ton IP publique au format CIDR (ex: 1.2.3.4/32), pour autoriser le SSH. Trouve-la avec: curl -s ifconfig.me"
  type        = string
}
