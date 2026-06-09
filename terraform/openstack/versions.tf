terraform {
  required_version = ">= 1.5"

  backend "local" {
    path = "/home/baro/terraform-state/openstack/terraform.tfstate"
  }

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

provider "openstack" {
  auth_url            = var.auth_url
  user_name           = var.user_name
  password            = var.password
  project_name        = var.project_name
  user_domain_name    = var.user_domain_name
  project_domain_name = var.project_domain_name
  region              = var.region
}
