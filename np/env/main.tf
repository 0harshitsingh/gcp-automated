provider "google" {
  region = "us-east4"
}

variable "org_id" {}
variable "billing_account" {}
variable "env" {}                          # dev, qa or uat
variable "link_billing" { default = true } # false = project only, no billing

# Find the folders from Step 1
data "google_active_folder" "host_np" {
  display_name = "host-np"
  parent       = "organizations/${var.org_id}"
}

data "google_active_folder" "spoke_np" {
  display_name = "spoke-np"
  parent       = "organizations/${var.org_id}"
}

# ---------- Host project ----------
resource "google_project" "host" {
  name                = "host-prj-${var.env}"
  project_id          = "host-prj-${var.env}-singh-lab"
  folder_id           = data.google_active_folder.host_np.name
  billing_account     = var.link_billing ? var.billing_account : null
  auto_create_network = false
}

resource "google_project_service" "host_compute" {
  count   = var.link_billing ? 1 : 0
  project = google_project.host.project_id
  service = "compute.googleapis.com"
}

resource "google_compute_shared_vpc_host_project" "host" {
  count      = var.link_billing ? 1 : 0
  project    = google_project.host.project_id
  depends_on = [google_project_service.host_compute]
}

# ---------- Spoke project ----------
resource "google_project" "spoke" {
  name                = "spoke-prj-${var.env}"
  project_id          = "spoke-prj-${var.env}-singh-lab"
  folder_id           = data.google_active_folder.spoke_np.name
  billing_account     = var.link_billing ? var.billing_account : null
  auto_create_network = false
}

resource "google_project_service" "spoke_compute" {
  count   = var.link_billing ? 1 : 0
  project = google_project.spoke.project_id
  service = "compute.googleapis.com"
}

# Attach spoke to host
resource "google_compute_shared_vpc_service_project" "attach" {
  count           = var.link_billing ? 1 : 0
  host_project    = google_project.host.project_id
  service_project = google_project.spoke.project_id
  depends_on = [
    google_compute_shared_vpc_host_project.host,
    google_project_service.spoke_compute,
  ]
}

output "host_project_id"  { value = google_project.host.project_id }
output "spoke_project_id" { value = google_project.spoke.project_id }
