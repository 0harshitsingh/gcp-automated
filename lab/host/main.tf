provider "google" {
  region = "us-east4"
}

variable "org_id" {}
variable "billing_account" {}

resource "google_folder" "host" {
  display_name = "host"
  parent       = "organizations/${var.org_id}"
}

# Turns this project into a Shared VPC host
resource "google_compute_shared_vpc_host_project" "host" {
  project    = module.project.project_id
  depends_on = [module.project]
}

output "host_project_id" {
  value = module.project.project_id
}

# new add
variable "service_project_id" {}
variable "admin_user" {}

# Look up the spoke project's number (needed for its service account)
data "google_project" "service" {
  project_id = var.service_project_id
}

resource "google_compute_network" "vpc" {
  name                    = "shared-vpc"
  project                 = module.project.project_id
  auto_create_subnetworks = false
  depends_on              = [module.project]
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "spoke-subnet"
  project                  = module.project.project_id
  region                   = "us-east4"
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.10.0.0/24"
  private_ip_google_access = true
}

# Let you create resources on this subnet from the spoke project
resource "google_compute_subnetwork_iam_member" "admin_user" {
  project    = module.project.project_id
  region     = google_compute_subnetwork.subnet.region
  subnetwork = google_compute_subnetwork.subnet.name
  role       = "roles/compute.networkUser"
  member     = "user:${var.admin_user}"
}

# Let the spoke project's Google-managed service account use the subnet
resource "google_compute_subnetwork_iam_member" "service_project" {
  project    = module.project.project_id
  region     = google_compute_subnetwork.subnet.region
  subnetwork = google_compute_subnetwork.subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${data.google_project.service.number}@cloudservices.gserviceaccount.com"
}

#add more
# GKE API must also be enabled on the host project
resource "google_compute_subnetwork" "gke" {
  name                     = "gke-subnet"
  project                  = module.project.project_id
  region                   = "us-east4"
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.20.0.0/24" # nodes
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.21.0.0/16" # pods
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.22.0.0/20" # services
  }
}

locals {
  gke_subnet_users = [
    "user:${var.admin_user}",
    "serviceAccount:${data.google_project.service.number}@cloudservices.gserviceaccount.com",
    "serviceAccount:service-${data.google_project.service.number}@container-engine-robot.iam.gserviceaccount.com",
  ]
}

resource "google_compute_subnetwork_iam_member" "gke_users" {
  for_each   = toset(local.gke_subnet_users)
  project    = module.project.project_id
  region     = google_compute_subnetwork.gke.region
  subnetwork = google_compute_subnetwork.gke.name
  role       = "roles/compute.networkUser"
  member     = each.key
}

# GKE service agent needs this on the host project
resource "google_project_iam_member" "gke_host_agent" {
  project    = module.project.project_id
  role       = "roles/container.hostServiceAgentUser"
  member     = "serviceAccount:service-${data.google_project.service.number}@container-engine-robot.iam.gserviceaccount.com"
  depends_on = [module.project]
}

resource "google_compute_router" "router" {
  name    = "shared-vpc-router"
  project = module.project.project_id
  region  = "us-east4"
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "shared-vpc-nat"
  project                            = module.project.project_id
  region                             = "us-east4"
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

module "project" {
  source          = "../../modules/project"
  name            = "host-prj"
  project_id      = "host-prj-singh-lab"
  folder_id       = google_folder.host.name
  billing_account = var.billing_account
  services        = ["compute.googleapis.com", "container.googleapis.com"]
}

# Tells Terraform these are the SAME objects at new addresses (prevents destroy/recreate)
moved {
  from = google_project.host
  to   = module.project.google_project.this
}
moved {
  from = google_project_service.compute
  to   = module.project.google_project_service.this["compute.googleapis.com"]
}
moved {
  from = google_project_service.container_host
  to   = module.project.google_project_service.this["container.googleapis.com"]
}
