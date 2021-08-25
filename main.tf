terraform {
  required_providers {
    #aws = {
      #source  = "hashicorp/aws"
    #}
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.20.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
  access_key = "XXXX"
  secret_key = "XXXX"
}

# Create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
     Name = "production"
    }
}

resource "aws_internet_gateway" "gw" {
   vpc_id = aws_vpc.prod-vpc.id
}



resource "aws_route_table" "prod-route-table" {
   vpc_id = aws_vpc.prod-vpc.id

   route {
     cidr_block = "0.0.0.0/0"  
     gateway_id = aws_internet_gateway.gw.id
    }

   route {
     ipv6_cidr_block = "::/0"
     gateway_id      = aws_internet_gateway.gw.id
    }

   tags = {
     Name = "Prod"
    }
}


resource "aws_subnet" "subnet-1" {
   vpc_id            = aws_vpc.prod-vpc.id
   cidr_block        = "10.0.1.0/24"
   availability_zone = "us-west-1a"

   tags = {
     Name = "prod-subnet"
    }
}



resource "aws_route_table_association" "a" {
   subnet_id      = aws_subnet.subnet-1.id
   route_table_id = aws_route_table.prod-route-table.id
}



resource "aws_security_group" "allow_web" {
   name        = "allow_web_traffic"
   description = "Allow Web inbound traffic"
   vpc_id      = aws_vpc.prod-vpc.id

   ingress {
     description = "HTTPS"
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
    }
   ingress {
     description = "HTTP"
     from_port   = 80
     to_port     = 80
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
    }
     ingress {
     description = "NodePort WordPress"
     from_port   = 30000
     to_port     = 30000
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
    }

   ingress {
     description = "HTTP"
     from_port   = 6443
     to_port     = 6443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
    }
   ingress {
     description = "SSH"
     from_port   = 22
     to_port     = 22
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
    }
   ingress {
     description = "MYSQL/Aurora"
     from_port   = 3306
     to_port     = 3306
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
    }
     # Below 6783 and 6784 port are opened for Weave Network for kubernetes
    ingress {
     description = "Weave Network TCP"
     from_port   = 6783
     to_port     = 6783
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
    }
    #ingress {
     #description = "Weave Network UDP"
     #from_port   = 6783
     #to_port     = 6784
     #protocol    = "udp"
     #cidr_blocks = ["0.0.0.0/0"]
    #}

   egress {
     from_port   = 0
     to_port     = 0
     protocol    = "-1"
     cidr_blocks = ["0.0.0.0/0"]
    }

   tags = {
     Name = "allow_web"
    }
}


#master instance
resource "aws_network_interface" "web-server-nic" {
   subnet_id       = aws_subnet.subnet-1.id
   private_ips     = ["10.0.1.50"]
   security_groups = [aws_security_group.allow_web.id]

}
resource "aws_eip" "one" {
   vpc                       = true
   network_interface         = aws_network_interface.web-server-nic.id
   associate_with_private_ip = "10.0.1.50"
   depends_on                = [aws_internet_gateway.gw] 
}

#worker instance
resource "aws_network_interface" "web-server-nic-1" {
   subnet_id       = aws_subnet.subnet-1.id
   private_ips     = ["10.0.1.51"]
   security_groups = [aws_security_group.allow_web.id]

}
resource "aws_eip" "two" {
   vpc                       = true
   network_interface         = aws_network_interface.web-server-nic-1.id
   associate_with_private_ip = "10.0.1.51"
   depends_on                = [aws_internet_gateway.gw] 
}

#worker 2 instance
resource "aws_network_interface" "web-server-nic-2" {
   subnet_id       = aws_subnet.subnet-1.id
   private_ips     = ["10.0.1.52"]
   security_groups = [aws_security_group.allow_web.id]

}
resource "aws_eip" "three" {
   vpc                       = true
   network_interface         = aws_network_interface.web-server-nic-2.id
   associate_with_private_ip = "10.0.1.52"
   depends_on                = [aws_internet_gateway.gw] 
}

#OUTPUTS
output "master_public_ip" {
   value = aws_eip.one.public_ip
}

output "worker_public_ip" {
   value = aws_eip.two.public_ip
}
output "worker2_public_ip" {
   value = aws_eip.three.public_ip
}

# WORKER INSTANCE
resource "aws_instance" "worker" {
   ami               = "ami-07b068f843ec78e72"  ##ubuntu 18.04 
   instance_type     = "t2.medium"
   availability_zone = "us-west-1a"  ## make sure that this matches the subnet
   key_name          = "main-key"  ## your key-name

   network_interface {
     device_index         = 0
     network_interface_id = aws_network_interface.web-server-nic-1.id
    }

   user_data = <<-EOF
                #!/bin/bash
                ## sudo su -
                git clone https://ayteakkaya536:XXXX@github.com/ayteakkaya536/infra-optimization-public.git
                cd infra-optimization
                sudo chmod 400 main-key.pem
                sudo chmod 777 worker.sh
                ./worker.sh
                 EOF
   tags = {
     Name = "worker"
    }
}

# WORKER 2 INSTANCE
resource "aws_instance" "worker2" {
   ami               = "ami-07b068f843ec78e72"  ##ubuntu 18.04 
   instance_type     = "t2.medium"
   availability_zone = "us-west-1a"  ## make sure that this matches the subnet
   key_name          = "main-key"  ## your key-name

   network_interface {
     device_index         = 0
     network_interface_id = aws_network_interface.web-server-nic-2.id
    }

   user_data = <<-EOF
                #!/bin/bash
                ## sudo su -
                git clone https://ayteakkaya536:XXXX@github.com/ayteakkaya536/infra-optimization-public.git
                cd infra-optimization
                sudo chmod 400 main-key.pem
                sudo chmod 777 worker.sh
                ./worker.sh
                 EOF
   tags = {
     Name = "worker2"
    }
}

#MASTER Instance
resource "aws_instance" "master" {
   ami               = "ami-07b068f843ec78e72"  ##ubuntu 18.04 #"ami-0d382e80be7ffdae5" temp
   instance_type     = "t2.medium"
   availability_zone = "us-west-1a"  ## make sure that this matches the subnet
   key_name          = "main-key"  ## your key-name

   network_interface {
     device_index         = 0
     network_interface_id = aws_network_interface.web-server-nic.id
    }

   user_data = <<-EOF
                #!/bin/bash
                ## sudo su -
                git clone https://ayteakkaya536:XXXX@github.com/ayteakkaya536/infra-optimization-public.git
                cd infra-optimization
                sudo chmod 400 main-key.pem
                sudo chmod 777 master.sh
                #sudo swapoff -a
                ./master.sh

                 EOF
   tags = {
     Name = "master"
    }
}





