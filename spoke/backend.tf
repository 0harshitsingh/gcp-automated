terraform {
  backend "gcs" {
    bucket = "singh-tf-state"
    prefix = "spoke/service-prj"
  }
}
