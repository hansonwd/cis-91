
variable "credentials_file" { 
  default = "/home/wil9640/cis-91-360404-ed390593b5ca.json" 
}

variable "project" {
  default = "cis-91-360404"
}

variable "region" {
  default = "us-west1"
}

variable "zone" {
  default = "us-west1-a"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  region  = var.region
  zone    = var.zone 
  project = var.project
}

resource "google_compute_network" "vpc_network" {
  name = "cis91-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "cis91"
  machine_type = "e2-micro"
  allow_stopping_for_update = true
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }

  service_account {
    email  = google_service_account.lab08-service-account.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "default-firewall" {
  name = "default-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22", "80", "3000", "5000"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_service_account" "lab08-service-account" {
  account_id   = "lab08-service-account"
  display_name = "lab08-service-account"
  description = "Service account for lab 08"
}

resource "google_project_iam_member" "project_member" {
  role = "roles/compute.viewer"
  member = "serviceAccount:${google_service_account.lab08-service-account.email}"
}

output "external-ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}
