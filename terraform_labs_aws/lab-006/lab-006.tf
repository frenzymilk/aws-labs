resource "aws_vpc" "lab_006_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "lab-006"
  }
}

# networking

data "aws_route_table" "default_routetable" {
  vpc_id = aws_vpc.lab_006_vpc.id
}

resource "aws_route" "r" {
  route_table_id         = data.aws_route_table.default_routetable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab_006_gw.id
}

resource "aws_subnet" "lab_006_az1_sub" {
  vpc_id                  = aws_vpc.lab_006_vpc.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = var.aws_region_az1
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-006"
  }
}

resource "aws_subnet" "lab_006_az2_sub" {
  vpc_id                  = aws_vpc.lab_006_vpc.id
  cidr_block              = "192.168.3.0/24"
  availability_zone       = var.aws_region_az2
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-006"
  }
}

resource "aws_internet_gateway" "lab_006_gw" {
  vpc_id = aws_vpc.lab_006_vpc.id
  tags = {
    Name = "lab-006"
  }
}

resource "aws_route_table_association" "lab_006_az1_rta" {
  subnet_id      = aws_subnet.lab_006_az1_sub.id
  route_table_id = data.aws_route_table.default_routetable.id
}

resource "aws_route_table_association" "lab_006_az2_rta" {
  subnet_id      = aws_subnet.lab_006_az2_sub.id
  route_table_id = data.aws_route_table.default_routetable.id
}

# auto scaling

resource "aws_launch_configuration" "configuration" {
  name_prefix     = "autoscaling_template_"
  image_id        = var.ec2_ami
  instance_type   = var.ec2_instance_type
  security_groups = [aws_security_group.remote_http_access_sg.id]
  user_data       = <<-EOL
                    #!/bin/bash -xe
                    yum update -y
                    amazon-linux-extras install epel -y
                    yum install stress -y
                    yum install httpd -y
                    systemctl enable httpd
                    systemctl start httpd
                    cd /var/www/html
                    myname = $(hostname)
                    echo "This is INSTANCE $myname " > index.html
                    EOL


}

resource "aws_autoscaling_group" "autoscale" {
  name                 = "autoscaling-group"
  desired_capacity     = 2
  max_size             = 3
  min_size             = 2
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]
  vpc_zone_identifier  = [aws_subnet.lab_006_az1_sub.id, aws_subnet.lab_006_az2_sub.id]
  launch_configuration = aws_launch_configuration.configuration.name
}

# security groups

resource "aws_security_group" "remote_http_access_sg" {
  name        = "AWS remote access"
  description = "Enable HTTP  access from loadbalancer"
  vpc_id      = aws_vpc.lab_006_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

}
