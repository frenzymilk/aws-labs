variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
  type        = string
}

variable "aws_region_az1" {
  description = "AWS Region"
  default     = "use1-az1"
  type        = string
}

variable "aws_region_az2" {
  description = "AWS Region"
  default     = "use1-az2"
  type        = string
}

variable "ec2_ami" {
  description = "AWS EC2 ami"
  default     = "ami-0440d3b780d96b29d"
  type        = string
}

variable "ec2_instance_type" {
  description = "AWS EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ec2_ssh_key" {
  description = "AWS EC2 ssh access key"
  type        = string
  sensitive   = true
}

variable "my_public_ip" {
  description = "My public IP address"
  type        = string
  sensitive   = true
}

variable "resource_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
  default = {
    project     = "project-aws-lab",
    environment = "dev"
  }
  validation {
    condition     = length(var.resource_tags["project"]) <= 16 && length(regexall("[^a-zA-Z0-9-]", var.resource_tags["project"])) == 0
    error_message = "The project tag must be no more than 16 characters, and only contain letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.resource_tags["environment"]) <= 8 && length(regexall("[^a-zA-Z0-9-]", var.resource_tags["environment"])) == 0
    error_message = "The environment tag must be no more than 8 characters, and only contain letters, numbers, and hyphens."
  }
}
