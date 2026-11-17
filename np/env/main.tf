provider "google" {
  region = "us-east4"
}

variable "org_id" {}
variable "billing_account" {}
variable "env" {}                           # dev, qa or uat
variable "link_billing" { default = false } # false = project only, no billing

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
resource "google_compute_shared_vpc_host_project" "host" {
  count      = var.link_billing ? 1 : 0
  project    = module.host_project.project_id
  depends_on = [module.host_project]
}

# ---------- Spoke project ----------
# Attach spoke to host
resource "google_compute_shared_vpc_service_project" "attach" {
  count           = var.link_billing ? 1 : 0
  host_project    = module.host_project.project_id
  service_project = module.spoke_project.project_id
  depends_on = [
    google_compute_shared_vpc_host_project.host,
    module.spoke_project,
  ]
}

output "host_project_id" { value = module.host_project.project_id }
output "spoke_project_id" { value = module.spoke_project.project_id }

module "host_project" {
  source          = "../../modules/project"
  name            = "host-prj-${var.env}"
  project_id      = "host-prj-${var.env}-singh-lab"
  folder_id       = data.google_active_folder.host_np.name
  billing_account = var.link_billing ? var.billing_account : null
  services        = var.link_billing ? ["compute.googleapis.com"] : []
}

module "spoke_project" {
  source          = "../../modules/project"
  name            = "spoke-prj-${var.env}"
  project_id      = "spoke-prj-${var.env}-singh-lab"
  folder_id       = data.google_active_folder.spoke_np.name
  billing_account = var.link_billing ? var.billing_account : null
  services        = var.link_billing ? ["compute.googleapis.com"] : []
}

# Same objects at new addresses (prevents destroy/recreate)
moved {
  from = google_project.host
  to   = module.host_project.google_project.this
}
moved {
  from = google_project.spoke
  to   = module.spoke_project.google_project.this
}
moved {
  from = google_project_service.host_compute[0]
  to   = module.host_project.google_project_service.this["compute.googleapis.com"]
}
moved {
  from = google_project_service.spoke_compute[0]
  to   = module.spoke_project.google_project_service.this["compute.googleapis.com"]
}
