terraform {
  backend "gcs" {
    bucket = "singh-tf-state"
    prefix = "host/host-prj"
  }
}
