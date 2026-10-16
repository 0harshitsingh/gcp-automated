provider "google" {
  region = "us-east4"
}

variable "org_id" {}
variable "billing_account" {}

resource "google_folder" "host" {
  display_name = "host"
  parent       = "organizations/${var.org_id}"
}

resource "google_project" "host" {
  name                = "host-prj"
  project_id          = "host-prj-singh-lab"   # must be globally unique
  folder_id           = google_folder.host.name
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "compute" {
  project = google_project.host.project_id
  service = "compute.googleapis.com"
}

# Turns this project into a Shared VPC host
resource "google_compute_shared_vpc_host_project" "host" {
  project    = google_project.host.project_id
  depends_on = [google_project_service.compute]
}

output "host_project_id" {
  value = google_project.host.project_id
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
  project                 = google_project.host.project_id
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "spoke-subnet"
  project                  = google_project.host.project_id
  region                   = "us-east4"
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.10.0.0/24"
  private_ip_google_access = true
}

# Let you create resources on this subnet from the spoke project
resource "google_compute_subnetwork_iam_member" "admin_user" {
  project    = google_project.host.project_id
  region     = google_compute_subnetwork.subnet.region
  subnetwork = google_compute_subnetwork.subnet.name
  role       = "roles/compute.networkUser"
  member     = "user:${var.admin_user}"
}

# Let the spoke project's Google-managed service account use the subnet
resource "google_compute_subnetwork_iam_member" "service_project" {
  project    = google_project.host.project_id
  region     = google_compute_subnetwork.subnet.region
  subnetwork = google_compute_subnetwork.subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${data.google_project.service.number}@cloudservices.gserviceaccount.com"
}

#add more
# GKE API must also be enabled on the host project
resource "google_project_service" "container_host" {
  project    = google_project.host.project_id
  service    = "container.googleapis.com"
  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "gke" {
  name                     = "gke-subnet"
  project                  = google_project.host.project_id
  region                   = "us-east4"
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.20.0.0/24"     # nodes
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.21.0.0/16"              # pods
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.22.0.0/20"              # services
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
  project    = google_project.host.project_id
  region     = google_compute_subnetwork.gke.region
  subnetwork = google_compute_subnetwork.gke.name
  role       = "roles/compute.networkUser"
  member     = each.key
}

# GKE service agent needs this on the host project
resource "google_project_iam_member" "gke_host_agent" {
  project = google_project.host.project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:service-${data.google_project.service.number}@container-engine-robot.iam.gserviceaccount.com"
  depends_on = [google_project_service.container_host]
}

resource "google_compute_router" "router" {
  name    = "shared-vpc-router"
  project = google_project.host.project_id
  region  = "us-east4"
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "shared-vpc-nat"
  project                            = google_project.host.project_id
  region                             = "us-east4"
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
