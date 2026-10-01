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
  key_name               = var.key_name_wg_gateway

  tags = { Name = "wg-gateway" }
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
  key_name               = var.key_name_monitoring

  root_block_device {
    volume_size = 30
  }

  tags = { Name = "monitoring" }
}

resource "aws_instance" "runner_ci" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.internal_only.id]
  key_name               = var.key_name_runner_ci

  tags = { Name = "runner-ci" }
}
