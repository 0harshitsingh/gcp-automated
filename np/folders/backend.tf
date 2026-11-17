terraform {
  backend "gcs" {
    bucket = "singh-tf-state"
    prefix = "np/folders"
  }
}
