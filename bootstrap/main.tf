provider "google" {
  region = "us-east4"
}

variable "org_id" {}
variable "billing_account" {}

resource "google_folder" "bootstrap" {
  display_name = "bootstrap"
  parent       = "organizations/${var.org_id}"
}

resource "google_project" "bootstrap" {
  name                = "taxi-bootstrap-prj"
  project_id          = "taxi-bootstrap-prj"   # must be globally unique
  folder_id           = google_folder.bootstrap.name
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "storage" {
  project = google_project.bootstrap.project_id
  service = "storage.googleapis.com"
}

resource "google_storage_bucket" "tfstate" {
  name                        = "singh-tf-state"   # must be globally unique
  project                     = google_project.bootstrap.project_id
  location                    = "US-EAST4"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  depends_on = [google_project_service.storage]
}
