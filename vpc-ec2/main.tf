terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "#"
  secret_key = "#"
}

#1 Create VPC
resource "aws_vpc" "FirstVpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "prod-vpc"
  }
}
#2 Create Internet Gateway
resource "aws_internet_gateway" "Prodgw" {
  vpc_id = aws_vpc.FirstVpc.id

  tags = {
    Name = "Prodgw"
  }
}
#3 Create Custome Route Table
resource "aws_route_table" "myRoute" {
  vpc_id = aws_vpc.FirstVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Prodgw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.Prodgw.id
  }

  tags = {
    Name = "MyRoute"
  }
}
#4 Create a subnet
resource "aws_subnet" "Public" {
  vpc_id     = aws_vpc.FirstVpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  #availability_zone_id = "use1-az2"

  tags = {
    Name = "Public"
  }
}
#5 Associate subnet with Route Table
resource "aws_route_table_association" "routeTableAsso" {
  subnet_id      = aws_subnet.Public.id
  route_table_id = aws_route_table.myRoute.id
}
#6 Create Sec Group to allow port 22,80,443
resource "aws_security_group" "Secgrp" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.FirstVpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp" 
    cidr_blocks      = ["0.0.0.0/0"]
    
  }
  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }
  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }



  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
#7 Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "eni" {
  subnet_id       = aws_subnet.Public.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.Secgrp.id]

}
#8 Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.eni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.Prodgw ]
}
#9 Create Ubuntu server and install| enable apache2
resource "aws_instance" "web" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t3.micro"
  availability_zone = "us-east-1a"
  #security_groups = a
  network_interface {
    network_interface_id = aws_network_interface.eni.id
    device_index         = 0
  }
  tags = {
    Name = "Ubuntu"
  }
  user_data = file("init.sh")
}