provider "google" {
  region = "us-east4"
}

variable "org_id" {}

resource "google_folder" "host_np" {
  display_name = "host-np"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "spoke_np" {
  display_name = "spoke-np"
  parent       = "organizations/${var.org_id}"
}
