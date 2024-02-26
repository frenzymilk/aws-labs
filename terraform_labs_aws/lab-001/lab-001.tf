resource "aws_instance" "simple_ec2" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_resource_type
  tags                   = var.resource_tags
  key_name               = var.ec2_ssh_key
  vpc_security_group_ids = [aws_security_group.remote_access_sg.id]
}

resource "aws_security_group" "remote_access_sg" {
  name        = "AWS remote access"
  description = "Enable ssh connection coming only from your public IP address"

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

  tags = var.resource_tags
}
