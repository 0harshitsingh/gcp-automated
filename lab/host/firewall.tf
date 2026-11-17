# Firewall rules for the GKE LoadBalancer in the Shared VPC host project.
# They target a FIXED node tag ("gke-lab-node", set on the node pool in the spoke),
# so a cluster rebuild no longer breaks them.

resource "google_compute_firewall" "gke_lb_web" {
  project       = "host-prj-singh-lab"
  name          = "allow-gke-lb-web"
  network       = "shared-vpc"
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-lab-node"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "gke_lb_healthcheck" {
  project       = "host-prj-singh-lab"
  name          = "allow-gke-lb-healthcheck"
  network       = "shared-vpc"
  direction     = "INGRESS"
  source_ranges = ["130.211.0.0/22", "209.85.152.0/22", "209.85.204.0/22", "35.191.0.0/16"]
  target_tags   = ["gke-lab-node"]

  allow {
    protocol = "tcp"
    ports    = ["10256"]
  }
}
