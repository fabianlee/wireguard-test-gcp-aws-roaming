
resource "google_compute_firewall" "wg-firewall" {
  depends_on = [google_compute_subnetwork.wg_subnetwork]

  name    = "default-allow-wg"
  network = "wg-network"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  allow {
    protocol = "udp"
    ports    = ["51820"]
  }
  allow {
    protocol = "icmp"
  }

  // Allow traffic from everywhere to instances with tag
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["wg-server"]
}

resource "google_compute_firewall" "web-firewall" {
  depends_on = [google_compute_subnetwork.private_subnetwork]

  name    = "default-allow-web"
  network = "wg-network"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  allow {
    protocol = "icmp"
  }

  // traffic could come from public subnet or wireguard cidr block
  // we will just be wide here
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

