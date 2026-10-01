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

  ingress {
    description = "SSH depuis mon IP uniquement"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

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

  ingress {
    description = "SSH depuis mon IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Trafic interne depuis le tunnel WireGuard (ajuste en Phase 1)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.8.0.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "infra-lab-internal-sg" }
}
