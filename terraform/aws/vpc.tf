resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "infra-lab-vpc" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = "infra-lab-igw" }
}

resource "aws_subnet" "public" { # nosemgrep: terraform.aws.security.aws-subnet-has-public-ip-address.aws-subnet-has-public-ip-address trivy:ignore:AWS-0164
  vpc_id     = aws_vpc.lab.id
  cidr_block = "10.0.1.0/24"
  # Choix assume pour ce lab : pas de NAT Gateway (payante) pour sortir sur
  # internet, donc les 3 VMs ont une IP publique directe, avec SSH restreint
  # a mon IP et le reste filtre par security group (voir security_groups.tf).
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = { Name = "infra-lab-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = { Name = "infra-lab-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
