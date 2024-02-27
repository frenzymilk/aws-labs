resource "aws_vpc" "lab_007_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "lab-007"
  }
}

# networking

data "aws_route_table" "default_routetable" {
  vpc_id = aws_vpc.lab_007_vpc.id
}

resource "aws_route" "r" {
  route_table_id         = aws_route_table.default_routetable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab_007_gw.id
}

resource "aws_subnet" "lab_007_az1_sub" {
  vpc_id                  = aws_vpc.lab_007_vpc.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = var.aws_region_az1
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-007"
  }
}

resource "aws_subnet" "lab_007_az2_sub" {
  vpc_id                  = aws_vpc.lab_007_vpc.id
  cidr_block              = "192.168.3.0/24"
  availability_zone       = var.aws_region_az2
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-007"
  }
}

resource "aws_internet_gateway" "lab_007_gw" {
  vpc_id = aws_vpc.lab_007_vpc.id
  tags = {
    Name = "lab-007"
  }
}

resource "aws_route_table_association" "lab_007_az1_rta" {
  subnet_id      = aws_subnet.lab_007_az1_sub.id
  route_table_id = aws_route_table.default_routetable.id
}

resource "aws_route_table_association" "lab_007_az2_rta" {
  subnet_id      = aws_subnet.lab_007_az2_sub.id
  route_table_id = aws_route_table.default_routetable.id
}

# auto scaling group

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
                    echo "This is INSTANCE ${HOSTNAME}" > index.html
                    EOL
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

}

resource "aws_autoscaling_group" "autoscale" {
  name                 = "autoscaling-group"
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]
  vpc_zone_identifier  = [aws_subnet.lab_007_az1_sub.id, aws_subnet.lab_007_az2_sub.id]
  launch_configuration = aws_launch_configuration.configuration.name
}

# load balancer

resource "aws_lb" "alb" {
  name               = "lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.lab_007_az1_sub.id, aws_subnet.lab_007_az2_sub.id]
  ip_address_type    = "ipv4"

  tags = resource_tags
}

resource "aws_lb_target_group" "target_group_http" {
  name        = "alb_http_tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.lab_007_vpc.id

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

resource "aws_autoscaling_attachment" "ec2_attach" {
  autoscaling_group_name = aws_autoscaling_group.autoscale.id
  alb_target_group_arn   = aws_lb_target_group.target_group_http.arn
}

# security groups

resource "aws_security_group" "remote_http_access_sg" {
  name        = "AWS remote access"
  description = "Enable HTTP forwarding and remote access"
  vpc_id      = aws_vpc.lab_007_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}/32"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["aws_security_group.alb_sg.id"]
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
  vpc_id      = aws_vpc.lab_007_vpc.id

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

  tags = resource_tags
}
