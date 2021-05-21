
resource "aws_key_pair" "my_keypair" {
  key_name   = var.aws_region
  public_key = file("${path.module}/../ansible_rsa.pub")
  tags = {
    Name = var.aws_region
  }
}


// https://gmusumeci.medium.com/how-to-get-the-latest-os-ami-in-aws-using-terraform-5b1fca82daff
data "aws_ami" "my_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [ var.ami_image_name ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "vpc_test"
  }
}

resource "aws_subnet" "public_subnet" {
  #name = not supported
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_cidr

  tags = {
    Name = "subnet_public"
  }
}
resource "aws_subnet" "private_subnet" {
  #name = not supported
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.private_subnet_cidr

  map_public_ip_on_launch = false

  tags = {
    Name = "subnet_private"
  }
}


# public wireguard server
resource "aws_instance" "wgserver" {
  depends_on = [ aws_internet_gateway.my_gateway ]
 
  #name = not supported
  ami = data.aws_ami.my_ami.id
  instance_type = var.ami_image_type
  subnet_id = aws_subnet.public_subnet.id
  key_name = aws_key_pair.my_keypair.key_name

  // static private IP
  private_ip = cidrhost(var.subnet_cidr,10)
  // public IP for ssh
  associate_public_ip_address = true

  vpc_security_group_ids = [ aws_security_group.wireguard_sg.id ]
  tags = {
    Name = "aws-ubuntu-pub-wg"
  }
  # this works OK, it does set check to false
  # https://stackoverflow.com/questions/57504230/source-dest-check-in-aws-launch-configuration-in-terraform
  source_dest_check = false

  provisioner "remote-exec" {
    inline = [
      "sleep 15 && sudo apt-get update -q"
    ]
    connection {
      type = "ssh"
      #timeout = 200
      user = var.ami_image_username
      host = self.public_ip
      private_key = file("${path.module}/../ansible_rsa")
    }
  }

}

# internal apache web server
resource "aws_instance" "web" {

  #name = not supported
  ami = data.aws_ami.my_ami.id
  instance_type = var.ami_image_type
  subnet_id = aws_subnet.private_subnet.id
  key_name = aws_key_pair.my_keypair.key_name

  // static private IP
  private_ip = cidrhost(var.private_subnet_cidr,129)
  // only allow access via bastion
  associate_public_ip_address = false

  vpc_security_group_ids = [ aws_security_group.web_sg.id ]

  tags = {
    Name = "aws-ubuntu-priv-web"
  }

  # wait till route change done so we have stable outside connection
  depends_on = [ aws_internet_gateway.my_gateway ]

}


