terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# ------------------------------
# VPC
# ------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "devops-lab-vpc"
  }
}

# ------------------------------
# Subnets
# ------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-bastion"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "private-subnet-app"
  }
}

# ------------------------------
# Security Group for Bastion Host
# ------------------------------
resource "aws_security_group" "bastion" {
  name        = "devops-lab-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-lab-bastion-sg"
  }
}

# ------------------------------
# Internet Gateway + Routing
# ------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "devops-lab-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------
# NAT Gateway + Private Routing
# ------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "devops-lab-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------
# AMI Lookup (Ubuntu 22.04 LTS)
# ------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ------------------------------
# Bastion Host
# ------------------------------
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = "devops-lab-key" # <-- replace with your AWS key pair
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "bastion-host"
  }
}

# ------------------------------
# App Server (Private Subnet)
# ------------------------------
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  key_name               = "devops-lab-key"
  vpc_security_group_ids = [aws_security_group.bastion.id] # reusing SG for simplicity

  tags = {
    Name = "app-server"
  }
}

# ------------------------------
# Outputs
# ------------------------------
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-devops-lab"
    key            = "devops-lab/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-lock"
  }
}


