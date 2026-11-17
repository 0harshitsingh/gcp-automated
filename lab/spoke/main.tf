provider "google" {
  region = "us-east4"
}

variable "org_id" {}
variable "billing_account" {}
variable "host_project_id" {}

resource "google_folder" "spoke" {
  display_name = "spoke"
  parent       = "organizations/${var.org_id}"
}

# Attaches this project to the Shared VPC host
resource "google_compute_shared_vpc_service_project" "attach" {
  host_project    = var.host_project_id
  service_project = module.project.project_id
  depends_on      = [module.project]
}

output "service_project_id" {
  value = module.project.project_id
}

#must to add for creation of robotsa
# ---------- Node service account ----------
resource "google_service_account" "gke_nodes" {
  project      = module.project.project_id
  account_id   = "gke-nodes"
  display_name = "GKE node SA"
}

locals {
  node_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ]
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset(local.node_roles)
  project  = module.project.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ---------- Cluster ----------
resource "google_container_cluster" "gke" {
  name                = "lab-gke"
  project             = module.project.project_id
  location            = "us-east4-a"
  deletion_protection = false

  network    = "projects/${var.host_project_id}/global/networks/shared-vpc"
  subnetwork = "projects/${var.host_project_id}/regions/us-east4/subnetworks/gke-subnet"

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  depends_on = [module.project]
}

# ---------- Node pool ----------
resource "google_container_node_pool" "primary" {
  name       = "primary"
  project    = module.project.project_id
  location   = "us-east4-a"
  cluster    = google_container_cluster.gke.name
  node_count = var.node_count

  node_config {
    machine_type    = "e2-medium"
    disk_size_gb    = 50
    disk_type       = "pd-standard"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = ["gke-lab-node"]
  }

  depends_on = [google_project_iam_member.gke_nodes]
}


variable "node_count" {
  default = 0 # lab is off by default; use -var node_count=2 to turn it on
}

module "project" {
  source          = "../../modules/project"
  name            = "service-prj"
  project_id      = "service-prj-singh-lab"
  folder_id       = google_folder.spoke.name
  billing_account = var.billing_account
  services        = ["compute.googleapis.com", "container.googleapis.com"]
}

# Tells Terraform these are the SAME objects at new addresses (prevents destroy/recreate)
moved {
  from = google_project.service
  to   = module.project.google_project.this
}
moved {
  from = google_project_service.compute
  to   = module.project.google_project_service.this["compute.googleapis.com"]
}
moved {
  from = google_project_service.container
  to   = module.project.google_project_service.this["container.googleapis.com"]
}
