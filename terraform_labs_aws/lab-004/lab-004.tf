resource "aws_instance" "simple_ec2" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_ssh_key
  tags = {
    Name = "simple-ec2"
  }
  vpc_security_group_ids = [aws_security_group.bastion_access_sg.id]
  subnet_id              = aws_subnet.lab_004_private_sub.id
}

resource "aws_instance" "bastion_ec2" {
  ami               = var.ec2_ami
  instance_type     = var.ec2_instance_type
  source_dest_check = false
  tags = {
    Name = "bastion-ec2"
  }
  key_name               = var.ec2_ssh_key
  subnet_id              = aws_subnet.lab_004_public_sub.id
  vpc_security_group_ids = [aws_security_group.nat_bastion_access_sg.id]

  user_data = <<-EOL
              #!/bin/bash -xe
              yum install -y iptables-services 
              systemctl enable iptables
              systemctl start iptables
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/custom-ip-forwarding.conf
              sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf
              interface=\$(netstat -i | awk 'NR==3{ print $1 }')
              /sbin/iptables -t nat -A POSTROUTING -o \$interface -j MASQUERADE
              /sbin/iptables -F FORWARD
              service iptables save
              EOL
}

resource "aws_network_interface" "bastion_eni" {
  subnet_id       = aws_subnet.lab_004_public_sub.id
  private_ips     = ["192.168.1.10"]
  security_groups = [aws_security_group.nat_bastion_access_sg.id]

  attachment {
    instance     = aws_instance.bastion_ec2.id
    device_index = 1
  }
}

# network access


resource "aws_vpc" "lab_004_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "lab-004"
  }
}

resource "aws_subnet" "lab_004_private_sub" {
  vpc_id            = aws_vpc.lab_004_vpc.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = var.aws_region_az1
  tags = {
    Name = "lab-004"
  }
}

# nat conf

resource "aws_route_table" "lab_004_nat_rt" {
  vpc_id = aws_vpc.lab_004_vpc.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.bastion_eni.id
  }
}

resource "aws_route_table_association" "lab_004_nat_rta" {
  subnet_id      = aws_subnet.lab_004_private_sub.id
  route_table_id = aws_route_table.lab_004_nat_rt.id
}

# public conf

resource "aws_subnet" "lab_004_public_sub" {
  vpc_id                  = aws_vpc.lab_004_vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = var.aws_region_az1
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-004"
  }
}

resource "aws_internet_gateway" "lab_004_gw" {
  vpc_id = aws_vpc.lab_004_vpc.id
  tags = {
    Name = "lab-004"
  }
}

resource "aws_route_table" "lab_004_rt" {
  vpc_id = aws_vpc.lab_004_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_004_gw.id
  }
}

resource "aws_route_table_association" "lab_004_public_rta" {
  subnet_id      = aws_subnet.lab_004_public_sub.id
  route_table_id = aws_route_table.lab_004_rt.id
}

# security groups

resource "aws_security_group" "nat_bastion_access_sg" {
  name        = "AWS remote access"
  description = "Enable HTTP forwarding and remote access"
  vpc_id      = aws_vpc.lab_004_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.simple_ec2.private_ip}/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.simple_ec2.private_ip}/32"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.simple_ec2.private_ip}/32"]
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
  vpc_id      = aws_vpc.lab_004_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

}
