variable "aws_region" {
  description = "Region AWS utilisee pour le lab"
  type        = string
  default     = "eu-west-3"
}

variable "my_ip" {
  description = "Ton IP publique au format CIDR (ex: 1.2.3.4/32), pour autoriser le SSH. Trouve-la avec: curl -s ifconfig.me"
  type        = string
}

variable "key_name_wg_gateway" {
  description = "Nom de la paire de cles EC2 existante pour wg-gateway"
  type        = string
  default     = "wg-gateway"
}

variable "key_name_monitoring" {
  description = "Nom de la paire de cles EC2 existante pour monitoring"
  type        = string
  default     = "monitoring"
}

variable "key_name_runner_ci" {
  description = "Nom de la paire de cles EC2 existante pour runner-ci"
  type        = string
  default     = "runner-ci"
}
