variable "name" {
    type        = string
    description = "Name of EC2 instance"
}
variable "region" {
    type        = string
    description = "Region where to deploy"
    default     = "eu-west-1"
}
data "aws_vpc" "default" {
  default = true
} 

data "aws_subnet_ids" "destination" {
  vpc_id = data.aws_vpc.default.id
  filter {
      name = "availability-zone"
      values = [var.region+"a"]
  }
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
  for_each      = data.aws_subnet_ids.destination.ids
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = each.value
  associate_public_ip_address = true
  tags = {
    Name = var.name
  }
}
