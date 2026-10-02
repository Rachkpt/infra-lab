# wg-gateway : seule VM exposee publiquement (WireGuard + HTTPS)
resource "aws_security_group" "wg_gateway" {
  name        = "wg-gateway-sg"
  description = "WireGuard, HTTPS et SSH restreint a mon IP"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "WireGuard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (Traefik)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # CGNAT cote FAI local : l'IP change trop souvent pour un filtrage fiable.
  # Protection restante : authentification par cle uniquement (pas de mot
  # de passe SSH actif sur ces images cloud-init).
  # trivy:ignore:AWS-0099
  ingress {
    description = "SSH (cle uniquement, IP source non filtrable via CGNAT)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Trafic interne du VPC a router vers le tunnel WireGuard"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]
  }

  # Egress large accepte pour ce lab (apt, docker, WireGuard, DNS...) :
  # restreindre precisement casserait regulierement pour peu de benefice
  # reel ici (pas de donnees sensibles a proteger en sortie).
  # trivy:ignore:AWS-0104
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "wg-gateway-sg" }
}

# monitoring et runner-ci : pas d'acces public direct, uniquement SSH perso
# + reseau interne du tunnel WireGuard (joignable une fois la Phase 1 faite)
resource "aws_security_group" "internal_only" {
  name        = "infra-lab-internal-sg"
  description = "SSH depuis mon IP + trafic interne via WireGuard"
  vpc_id      = aws_vpc.lab.id

  # trivy:ignore:AWS-0099
  ingress {
    description = "SSH (cle uniquement, IP source non filtrable via CGNAT)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Trafic interne depuis le VPC, le tunnel WireGuard et le reseau Proxmox"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24", "10.8.0.0/24", "10.10.10.0/24"]
  }

  # trivy:ignore:AWS-0104
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "infra-lab-internal-sg" }
}
