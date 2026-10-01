data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "wg_gateway" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.wg_gateway.id]
  key_name               = aws_key_pair.infra_lab.key_name

  # Necessaire pour que cette VM puisse router/forwarder du trafic qui ne
  # lui est pas destine (tunnel WireGuard vers le reseau Proxmox local).
  source_dest_check = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = { Name = "wg-gateway" }
}

# Permet a monitoring/runner-ci (meme route table) de joindre le reseau
# Proxmox local (VMs k3s) et le reseau du tunnel WireGuard en passant par
# wg-gateway, qui fait office de routeur.
resource "aws_route" "to_wireguard_net" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = aws_instance.wg_gateway.primary_network_interface_id
}

resource "aws_route" "to_proxmox_net" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "10.10.10.0/24"
  network_interface_id   = aws_instance.wg_gateway.primary_network_interface_id
}

resource "aws_eip" "wg_gateway" {
  instance = aws_instance.wg_gateway.id
  domain   = "vpc"

  tags = { Name = "wg-gateway-eip" }
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.internal_only.id]
  key_name               = aws_key_pair.infra_lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 30
    encrypted   = true
  }

  tags = { Name = "monitoring" }
}

resource "aws_instance" "runner_ci" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.internal_only.id]
  key_name               = aws_key_pair.infra_lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = { Name = "runner-ci" }
}
