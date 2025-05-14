locals {
  template_data = templatefile("${path.module}/startup.sh",{
    foo = "bar"
  })
}

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


# public wireguard server
resource "aws_instance" "wgserver" {
  #name = not supported
  ami = data.aws_ami.my_ami.id
  instance_type = var.ami_image_type
  subnet_id = aws_subnet.public_subnet.id
  key_name = aws_key_pair.my_keypair.key_name

  // static private IP
  private_ip = cidrhost(var.public_subnet_cidr,10)
  // public IP for ssh
  associate_public_ip_address = true

  vpc_security_group_ids = [ aws_security_group.wireguard_sg.id ]
  tags = {
    Name = "aws-ubuntu-pub-wg"
  }
  # Because this is a NAT server, need to disable source/dest check for VM
  source_dest_check = false

  # example of local file startup script
  user_data = file("${path.module}/startup.sh")

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

  depends_on = [ aws_internet_gateway.my_gateway ]
}

/*
data "template_file" "default" {
  template = file("${path.module}/startup.sh")
  vars = {
    foo = "bar"
  }
}
*/


# private apache web server
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

  # coming from template
  #user_data = data.template_file.default.rendered
  user_data = local.template_data

  # directly from file
  #user_data = file("${path.module}/startup.sh")

  # example of inline startup script
  # https://dev.to/liptanbiswas/how-to-put-variable-in-terraform-start-up-script-2i64
#  user_data = <<-EOF
#    #!/bin/bash
#    echo test user_data | sudo tee /tmp/user_data.log
#    curl http://169.254.169.254/latest/meta-data/local-ipv4 | sudo tee -a  /tmp/user_data.log
#  EOF

  tags = {
    Name = "aws-ubuntu-priv-web"
  }

  # wait till route change done so we have stable outside connection
  depends_on = [ aws_internet_gateway.my_gateway ]
}


