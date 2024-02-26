resource "aws_instance" "simple_ec2" {
  name          = "simple-ec2"
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type
  tags          = var.resource_tags
  subnet_id     = aws_subnet.lab_002_private_sub.id
}

resource "aws_instance" "bastion_ec2" {
  name                   = "bastion"
  ami                    = var.ec2_ami
  instance_type          = var.ec2_resource_type
  tags                   = var.resource_tags
  key_name               = var.ec2_ssh_key
  subnet_id              = aws_subnet.lab_002_public_sub.id
  vpc_security_group_ids = [aws_security_group.remote_access_sg.id]
}

# network access

resource "aws_vpc" "lab_002_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "lab-002"
  }
}

resource "aws_subnet" "lab_002_private_sub" {
  vpc_id            = aws_vpc.lab_002_vpc.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = var.aws_region_az1
  tags = {
    Name = "lab-002"
  }
}

# public conf

resource "aws_subnet" "lab_002_public_sub" {
  vpc_id                  = aws_vpc.lab_002_vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = var.aws_region_az1
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-002"
  }
}

resource "aws_internet_gateway" "lab_002_gw" {
  vpc_id = aws_vpc.lab_002_vpc.id
  tags = {
    Name = "lab-002"
  }
}

resource "aws_route_table" "lab_002_rt" {
  vpc_id = aws_vpc.lab_002_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_002_gw.id
  }
}

resource "aws_route_table_association" "lab_002_public_rta" {
  subnet_id      = aws_subnet.lab_002_public_sub.id
  route_table_id = aws_route_table.lab_002_rt.id
}

# security groups

resource "aws_security_group" "remote_access_sg" {
  name        = "AWS remote access"
  description = "Enable ssh connection coming only from your public IP address"
  vpc_id      = aws_vpc.lab_002_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = resource_tags
}


resource "aws_security_group" "bastion_access_sg" {
  name        = "Access from bastion host"
  description = "Enable ssh connection coming only from bastion host"
  vpc_id      = aws_vpc.lab_002_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.bastion_ec2.private_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

}
