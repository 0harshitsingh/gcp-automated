terraform {
  backend "gcs" {
    bucket = "singh-tf-state"
    prefix = "bootstrap"
  }
}
