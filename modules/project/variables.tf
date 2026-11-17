variable "name" {}
variable "project_id" {}
variable "folder_id" {}

variable "billing_account" {
  default = null # null = project only, no billing linked
}

variable "services" {
  type    = list(string)
  default = [] # APIs to enable, e.g. ["compute.googleapis.com"]
}
