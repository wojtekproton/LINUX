terraform {
  required_providers {
    aws = {
        source  = "hashicorp/aws"
        version = ">= 1.24.0"
    }
  }
}

variable "name" {
    type      = string
    description = "Name of EC2 instance"
}

data "aws_vpc" "default" {
  default = true
} 

data "aws_subnet_ids" "destination" {
  vpc_id = data.aws_vpc.default.id
}
data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    owners = ["099720109477"]
}

resource "aws_instance" "web" {
  # for_each      = data.aws_subnet_ids.destination.ids
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
 # subnet_id = each.value
  subnet_id     = tolist(data.aws_subnet_ids.destination.ids)[0]
  associate_public_ip_address = true
  tags = {
    Name = var.name
  }
}
