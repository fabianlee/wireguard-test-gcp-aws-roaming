resource "google_compute_network" "wg_network" {
  name = "wg-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "wg_subnetwork" {
  name          = "wg-subnetwork"
  ip_cidr_range = var.cidr_block
  region        = var.region
  network       = google_compute_network.wg_network.name

  depends_on = [google_compute_network.wg_network]
}
resource "google_compute_subnetwork" "private_subnetwork" {
  name          = "private-subnetwork"
  ip_cidr_range = var.private_cidr_block
  region        = var.region
  network       = google_compute_network.wg_network.name

  depends_on = [google_compute_network.wg_network]
}

# create a public ip for nat service
resource "google_compute_address" "nat-ip" {
  name = "nat-ip"
  project = var.project
  region  = var.region
}
# create a nat to allow private instances connect to internet
resource "google_compute_router" "nat-router" {
  name = "nat-router"
  network = google_compute_network.wg_network.name
}
resource "google_compute_router_nat" "nat-gateway" {
  name = "nat-gateway"
  router = google_compute_router.nat-router.name

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips = [ google_compute_address.nat-ip.self_link ]

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS" #"ALL_SUBNETWORKS_ALL_IP_RANGES" 
  subnetwork { 
     name = google_compute_subnetwork.private_subnetwork.id
     source_ip_ranges_to_nat = [ var.private_cidr_block ] # "ALL_IP_RANGES"
  }
  depends_on = [ google_compute_address.nat-ip ]
}


resource "google_compute_instance" "wgserver" {
  name         = "gcp-ubuntu-pub-wg"
  machine_type = var.machine_type
  zone         = var.zone
  can_ip_forward = true

  depends_on = [google_compute_network.wg_network,google_compute_subnetwork.wg_subnetwork]

  boot_disk {
    initialize_params {
      image = var.os_image
      type = "pd-ssd"
      size = "40"
    }
  }

  network_interface {
    network = "wg-network"
    subnetwork = "wg-subnetwork"
    network_ip = cidrhost(var.cidr_block,10)

    access_config {
      // empty block means ephemeral external IP
    }
  }


  // using ssh key attached directly to vm (not ssh key in project level metadata)  
  metadata = {
    ssh-keys = "ubuntu:${file("../ansible_rsa.pub")}"
  }

  // https://medium.com/slalom-technology/a-complete-gcp-environment-with-terraform-c087190366f0
#  metadata_startup_script = <<SCRIPT
#    sudo sysctl -w net.ipv4.ip_forward=1
#    SCRIPT

#    sudo apt-get update && sudo apt-get install apache2 -y
#    export HOSTNAME=$(hostname | tr -d '\n')
#    export PRIVATE_IP=$(curl -sf -H 'Metadata-Flavor:Google' http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip | tr -d '\n')
#    echo "<html><body><h1>Hello, World! From $HOSTNAME at $PRIVATE_IP</h1></body></html>" | sudo tee /var/www/html/index.html
#    SCRIPT


  # https://alex.dzyoba.com/blog/terraform-ansible/
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -q"
    ]
    connection {
      type = "ssh"
      #timeout = 200
      user = "ubuntu"
      host = self.network_interface.0.access_config.0.nat_ip
      private_key = file("${path.module}/../ansible_rsa")
    }
  }


  // Apply the firewall rule to allow external IPs to access this instance
  tags = ["wg-server"]
}

# all private wireguard traffic goes to public instance
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "other_route" {
  depends_on = [google_compute_instance.wgserver]

  name        = "route-wg-network-to-public-instance"
  dest_range  = var.wireguard_cidr
  network     = google_compute_network.wg_network.name
  next_hop_instance = google_compute_instance.self_link
  priority    = 100
}

resource "google_compute_instance" "web" {
  name         = "gcp-ubuntu-priv-web"
  machine_type = var.machine_type
  zone         = var.zone
  can_ip_forward = true

  depends_on = [google_compute_network.wg_network,google_compute_subnetwork.wg_subnetwork]

  boot_disk {
    initialize_params {
      image = var.os_image
      type = "pd-ssd"
      size = "40"
    }
  }

  network_interface {
    network = "wg-network"
    subnetwork = "private-subnetwork"
    network_ip = cidrhost(var.private_cidr_block,129)

    // no public IP wanted
    //access_config {
      // empty block means ephemeral external IP
    //}
  }


  // using ssh key attached directly to vm (not ssh key in project level metadata)  
  metadata = {
    ssh-keys = "ubuntu:${file("../ansible_rsa.pub")}"
  }

  // https://medium.com/slalom-technology/a-complete-gcp-environment-with-terraform-c087190366f0
#  metadata_startup_script = <<SCRIPT
#    sudo apt-get update && sudo apt-get install apache2 -y
#    export HOSTNAME=$(hostname | tr -d '\n')
#    export PRIVATE_IP=$(curl -sf -H 'Metadata-Flavor:Google' http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip | tr -d '\n')
#    echo "<html><body><h1>Hello, World! From $HOSTNAME at $PRIVATE_IP</h1></body></html>" | sudo tee /var/www/html/index.html
#    SCRIPT

  // Apply the firewall rule to allow external IPs to access this instance
  tags = ["web-server"]
}


