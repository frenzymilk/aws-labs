resource "aws_instance" "server_az1" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type
  tags = {
    Name = "server_az1"
  }
  subnet_id              = aws_subnet.lab_005_az1_sub.id
  vpc_security_group_ids = [aws_security_group.http_access_sg.id]

  user_data = <<-EOL
              #!/bin/bash -xe
              yum update -y
              yum install httpd -y
              systemctl enable httpd
              systemctl start httpd
              cd /var/www/html
              echo "This is an az1 instance" > index.html
              EOL
}

resource "aws_instance" "server_az2" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type
  tags = {
    Name = "server_az2"
  }
  subnet_id              = aws_subnet.lab_005_az2_sub.id
  vpc_security_group_ids = [aws_security_group.http_access_sg.id]

  user_data = <<-EOL
              #!/bin/bash -xe
              yum update -y
              yum install httpd -y
              systemctl enable httpd
              systemctl start httpd
              cd /var/www/html
              echo "This is an az2 instance" > index.html
              EOL
}

resource "aws_lb" "alb" {
  name               = "lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.lab_005_az1_sub.id, aws_subnet.lab_005_az2_sub.id]
  ip_address_type    = "ipv4"


}

resource "aws_lb_target_group" "target_http" {
  name        = "http-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.lab_005_vpc.id

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

resource "aws_lb_target_group_attachment" "ec2_attach_1" {
  target_group_arn = aws_lb_target_group.target_group_http.arn
  target_id        = aws_instance.server_az1.id
}


resource "aws_lb_target_group_attachment" "ec2_attach_2" {
  target_group_arn = aws_lb_target_group.target_group_http.arn
  target_id        = aws_instance.server_az2.id
}

resource "aws_vpc" "lab_005_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "lab-005"
  }
}

data "aws_route_table" "default_routetable" {
  vpc_id = aws_vpc.lab_005_vpc.id
}

resource "aws_route" "r" {
  route_table_id         = data.aws_route_table.default_routetable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab_005_gw.id
}

resource "aws_subnet" "lab_005_az1_sub" {
  vpc_id                  = aws_vpc.lab_005_vpc.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = var.aws_region_az1
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-005"
  }
}

resource "aws_subnet" "lab_005_az2_sub" {
  vpc_id                  = aws_vpc.lab_005_vpc.id
  cidr_block              = "192.168.3.0/24"
  availability_zone       = var.aws_region_az2
  map_public_ip_on_launch = true
  tags = {
    Name = "lab-005"
  }
}

resource "aws_internet_gateway" "lab_005_gw" {
  vpc_id = aws_vpc.lab_005_vpc.id
  tags = {
    Name = "lab-005"
  }
}

resource "aws_route_table_association" "lab_005_az1_rta" {
  subnet_id      = aws_subnet.lab_005_az1_sub.id
  route_table_id = data.aws_route_table.default_routetable.id
}

resource "aws_route_table_association" "lab_005_az2_rta" {
  subnet_id      = aws_subnet.lab_005_az2_sub.id
  route_table_id = data.aws_route_table.default_routetable.id
}

# security groups

resource "aws_security_group" "http_access_sg" {
  name        = "AWS remote access"
  description = "Enable HTTP forwarding and remote access"
  vpc_id      = aws_vpc.lab_005_vpc.id

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


}

resource "aws_security_group" "alb_sg" {
  name        = "http access"
  description = "Enable HTTP forwarding and remote access"
  vpc_id      = aws_vpc.lab_005_vpc.id

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
