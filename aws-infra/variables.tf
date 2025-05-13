// variables that MUST be overridden
variable "vpc_cidr" { }
variable "subnet_cidr" { }
variable "private_subnet_cidr" { }
variable "aws_region" { }
variable "other_vpc_cidr" { }

variable "wireguard_cidr" { default="10.0.14.0/24" }

// https://cloud-images.ubuntu.com/locator/ec2/
// aws ec2 describe-images --owners=099720109477 --output=text | grep "20\.04"

#variable "ami_image_name" { default="ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" }
#variable "ami_image_type" { default="t2.nano" }

# newest Ubuntu 24.04 image in May 2025
variable "ami_image_name" { default="ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" }
variable "ami_image_type" { default="t2.micro" } 

variable "ami_image_username" { default="ubuntu"}
