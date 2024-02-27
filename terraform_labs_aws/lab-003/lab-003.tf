resource "aws_instance" "simple_ec2" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  key_name               = var.ec2_ssh_key
  vpc_security_group_ids = [aws_security_group.bastion_access_sg.id]
  subnet_id              = aws_subnet.lab_003_private_sub.id
  tags = {
    Name = "simple_ec2"
  }
}

resource "aws_instance" "bastion_ec2" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type

  key_name               = var.ec2_ssh_key
  subnet_id              = aws_subnet.lab_003_public_sub.id
  vpc_security_group_ids = [aws_security_group.remote_access_sg.id]
  tags = {
    Name = "bastion_ec2"
  }
}

# network access

resource "aws_eip" "public_ip" {
  #domain = "vpc"
}

resource "aws_vpc" "lab_003_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "lab-003"
  }
}

resource "aws_subnet" "lab_003_private_sub" {
  vpc_id            = aws_vpc.lab_003_vpc.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = var.aws_region_az1
  tags = {
    Name = "lab-003"
  }
}

# nat conf

resource "aws_nat_gateway" "lab_003_nat_gw" {
  allocation_id = aws_eip.public_ip.id
  subnet_id     = aws_subnet.lab_003_public_sub.id

  tags = {
    Name = "lab-003"
  }

  depends_on = [aws_internet_gateway.lab_003_gw]
}

resource "aws_route_table" "lab_003_nat_rt" {
  vpc_id = aws_vpc.lab_003_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.lab_003_nat_gw.id
  }
}

resource "aws_route_table_association" "lab_003_nat_rta" {
  subnet_id      = aws_subnet.lab_003_private_sub.id
  route_table_id = aws_route_table.lab_003_nat_rt.id
}

# public conf

resource "aws_subnet" "lab_003_public_sub" {
  vpc_id                  = aws_vpc.lab_003_vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = var.aws_region_az1
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-003"
  }
}

resource "aws_internet_gateway" "lab_003_gw" {
  vpc_id = aws_vpc.lab_003_vpc.id
  tags = {
    Name = "lab-003"
  }
}

resource "aws_route_table" "lab_003_rt" {
  vpc_id = aws_vpc.lab_003_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_003_gw.id
  }
}

resource "aws_route_table_association" "lab_003_public_rta" {
  subnet_id      = aws_subnet.lab_003_public_sub.id
  route_table_id = aws_route_table.lab_003_rt.id
}

# security groups

resource "aws_security_group" "remote_access_sg" {
  name        = "AWS remote access"
  description = "Enable ssh connection coming only from your public IP address"
  vpc_id      = aws_vpc.lab_003_vpc.id

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


}


resource "aws_security_group" "bastion_access_sg" {
  name        = "Access from bastion host"
  description = "Enable ssh connection coming only from bastion host"
  vpc_id      = aws_vpc.lab_003_vpc.id

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


}
