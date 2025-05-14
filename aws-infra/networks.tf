resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "vpc_test"
  }
}

resource "aws_subnet" "public_subnet" {
  #name = not supported
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.public_subnet_cidr

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


resource "aws_internet_gateway" "my_gateway" {
  #name = not supported
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "gw_test"
  }
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc" // vpc=true is deprecated

  depends_on = [aws_internet_gateway.my_gateway]
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  depends_on    = [aws_internet_gateway.my_gateway]
  tags = {
    Name        = "nat"
  }
}


resource "aws_route_table" "my_routetable" {
  #name = not supported
  vpc_id = aws_vpc.my_vpc.id

  # if using ipv6, would need egress only igw
  #route {
  #  ipv6_cidr_block        = "::/0"
  #  egress_only_gateway_id = "${aws_egress_only_internet_gateway.foo.id}"
  #}

  tags = {
    Name = "rtable_test"
  }
}

resource "aws_route" "my_default_route" {
  route_table_id = aws_route_table.my_routetable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.my_gateway.id
}

# we don't need this for wireguard
#resource "aws_route" "my_route_othervpc" {
#  route_table_id = aws_route_table.my_routetable.id
#  destination_cidr_block = var.other_vpc_cidr
#
#  instance_id = aws_instance.wgserver.id
#
#  depends_on = [ aws_instance.wgserver ]
#}

resource "aws_route_table_association" "my_routetable_assoc" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.my_routetable.id
}



resource "aws_route_table" "private_routetable" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "private_rtable_test"
  }
}
resource "aws_route" "private_default_route" {
  route_table_id = aws_route_table.private_routetable.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}
resource "aws_route" "wireguard_route" {
  route_table_id = aws_route_table.private_routetable.id
  # routes wireguard CIDR to public wireguard instance for forwarding
  # actually links to network interface if you look at aws routing table
  destination_cidr_block = var.wireguard_cidr

  network_interface_id = aws_instance.web.primary_network_interface_id
}
resource "aws_route" "othervpc_route" {
  route_table_id = aws_route_table.private_routetable.id
  # routes other VPC to public wireguard instance for forwarding
  destination_cidr_block = var.other_vpc_cidr

  network_interface_id = aws_instance.wgserver.primary_network_interface_id
}
resource "aws_route_table_association" "private_routetable_assoc" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_routetable.id
}


resource "aws_security_group" "wireguard_sg" {
    name = "wireguard_sg"
    vpc_id = aws_vpc.my_vpc.id

    ingress {
    from_port = 51820
    to_port = 51820
    protocol = "udp" 
    cidr_blocks = ["0.0.0.0/0"] 
    }
    ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
    }
    ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
    }
    ingress {
    # all type
    # https://blog.jwr.io/terraform/icmp/ping/security/groups/2018/02/02/terraform-icmp-rules.html
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"] 
    }

    egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
    }


    tags = {
      Name = "wireguard_sg"
    }
}

resource "aws_security_group" "web_sg" {
    name = "web_sg"
    vpc_id = aws_vpc.my_vpc.id

    ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
    }
    ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    # receives traffic from its public side subnet, but also wireguard which looks like 10.0.14.0/24
    # so we just allow a wide net here
    cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
    # all type
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"] 
    }

    egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
    }


    tags = {
      Name = "web_sg"
    }
}

