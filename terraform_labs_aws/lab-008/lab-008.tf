resource "aws_vpc" "lab_008_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "lab-008"
  }
}

# auto scaling group

resource "aws_launch_configuration" "configuration" {
  name_prefix     = "autoscaling_template_"
  image_id        = var.ec2_ami
  instance_type   = var.ec2_instance_type
  security_groups = [aws_security_group.private_sg.id]
  user_data       = <<-EOL
                    #!/bin/bash -xe
                    yum update -y
                    amazon-linux-extras install epel -y
                    yum install stress -y
                    yum install httpd -y
                    systemctl enable httpd
                    systemctl start httpd
                    cd /var/www/html
                    echo "This is INSTANCE ${HOSTNAME}" > index.html
                    EOL
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

}

resource "aws_autoscaling_group" "autoscale" {
  name                 = "autoscaling-group"
  desired_capacity     = 2
  max_size             = 4
  min_size             = 2
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]
  vpc_zone_identifier  = [aws_subnet.lab_008_private_az1_sub.id, aws_subnet.lab_008_private_az2_sub.id]
  launch_configuration = aws_launch_configuration.configuration.name
}

# private subnets

resource "aws_subnet" "lab_008_private_az1_sub" {
  vpc_id            = aws_vpc.lab_008_vpc.id
  cidr_block        = "192.168.3.0/24"
  availability_zone = var.aws_region_az1
  tags = {
    Name = "lab-008"
  }
}

resource "aws_subnet" "lab_008_private_az2_sub" {
  vpc_id            = aws_vpc.lab_008_vpc.id
  cidr_block        = "192.168.4.0/24"
  availability_zone = var.aws_region_az2
  tags = {
    Name = "lab-008"
  }
}

# public subnets

resource "aws_subnet" "lab_008_public_az1_sub" {
  vpc_id                  = aws_vpc.lab_008_vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = var.aws_region_az1
  map_public_ip_on_launch = true

  tags = {
    Name = "lab-008"
  }
}

resource "aws_subnet" "lab_008_public_az2_sub" {
  vpc_id                  = aws_vpc.lab_008_vpc.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = var.aws_region_az2
  map_public_ip_on_launch = true

  tags = {
    Name = "lab-008"
  }
}

# application load balancer

resource "aws_lb" "alb" {
  name               = "lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.lab_008_public_az1_sub.id, aws_subnet.lab_008_public_az2_sub.id]
  ip_address_type    = "ipv4"

  tags = resource_tags
}

resource "aws_lb_target_group" "target_group_http" {
  name        = "alb_http_tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.lab_008_vpc.id

  health_check {
    enabled             = true
    interval            = 10
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "alb_listener_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_http.arn
  }
}

resource "aws_lb_target_group_attachment" "nat_attach_1" {
  target_group_arn = aws_lb_target_group.target_group_http.arn
  target_id        = aws_nat_gateway.lab_008_nat1_gw.id
}

resource "aws_lb_target_group_attachment" "nat_attach_2" {
  target_group_arn = aws_lb_target_group.target_group_http.arn
  target_id        = aws_nat_gateway.lab_008_nat2_gw.id
}

# internet gateway

resource "aws_internet_gateway" "lab_008_gw" {
  vpc_id = aws_vpc.lab_008_vpc.id
  tags = {
    Name = "lab-008"
  }
}

resource "aws_route_table" "lab_008_rt" {
  vpc_id = aws_vpc.lab_008_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_008_gw.id
  }
}

resource "aws_route_table_association" "lab_008_public1_rta" {
  subnet_id      = aws_subnet.lab_008_public_az1_sub.id
  route_table_id = aws_route_table.lab_008_rt.id
}

resource "aws_route_table_association" "lab_008_public2_rta" {
  subnet_id      = aws_subnet.lab_008_public_az2_sub.id
  route_table_id = aws_route_table.lab_008_rt.id
}

# nat gateway

resource "aws_eip" "public_ip1" {
  domain = "vpc"
}

resource "aws_eip" "public_ip2" {
  domain = "vpc"
}

resource "aws_nat_gateway" "lab_008_nat1_gw" {
  allocation_id = aws_eip.public_ip1.id
  subnet_id     = aws_subnet.lab_008_public_az1_sub
  depends_on    = [aws_internet_gateway.lab_008_gw]

  tags = {
    Name = "lab-008"
  }
}

resource "aws_route_table" "lab_008_nat1_rt" {
  vpc_id = aws_vpc.lab_008_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.lab_008_nat1_gw.id
  }
}

resource "aws_route_table_association" "lab_008_nat1_rta" {
  subnet_id      = aws_subnet.lab_008_private_az1_sub.id
  route_table_id = aws_route_table.lab_008_nat1_rt.id
}

resource "aws_nat_gateway" "lab_008_nat2_gw" {
  allocation_id = aws_eip.public_ip2.id
  subnet_id     = aws_subnet.lab_008_public_az2_sub
  depends_on    = [aws_internet_gateway.lab_008_gw]

  tags = {
    Name = "lab-008"
  }
}

resource "aws_route_table" "lab_008_nat2_rt" {
  vpc_id = aws_vpc.lab_008_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.lab_008_nat2_gw.id
  }
}

resource "aws_route_table_association" "lab_008_nat1_rta" {
  subnet_id      = aws_subnet.lab_008_private_az2_sub.id
  route_table_id = aws_route_table.lab_008_nat2_rt.id
}

# security groups

resource "aws_security_group" "private_sg" {
  name   = "Access on private instance"
  vpc_id = aws_vpc.lab_008_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = resource_tags
}

resource "aws_security_group" "alb_sg" {
  name        = "AWS remote access"
  description = "Enable HTTP forwarding and remote access"
  vpc_id      = aws_vpc.lab_008_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["192.168.3.0/24", "192.168.4.0/24"]
  }

  tags = resource_tags
}
