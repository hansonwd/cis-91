/*
William Hanson
Cabrillo College, CIS-91, Fall 2022
Assignment Lab 10
11/6/2022

Create service account with storage admin permissions and a
storage bucket. 
*/


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

resource "google_compute_instance" "vm-instance" {
  name         = "cis91"
  machine_type = "e2-micro"

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
  attached_disk {
    source = google_compute_disk.lab10-persistent.self_link
    device_name = "lab10-persistent"
  }
  service_account {
    email  = google_service_account.lab10-service-account.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "default-firewall" {
  name = "default-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_disk" "lab10-persistent" {
  name  = "lab10-persistent"
  type  = "pd-ssd"
  labels = {
    environment = "lab10"
  }
  size = "100"
}

data "google_iam_policy" "admin" {
  binding {
    role = "roles/iam.serviceAccountAdmin"
    members = [
      "serviceAccount:${google_service_account.lab10-service-account.email}",
    ]
  }
}

data "google_iam_policy" "bucket_policy" {
  binding {
    role = "roles/storage.admin"
    members = [
      "serviceAccount:${google_service_account.lab10-service-account.email}",
    ]
  }
}

resource "google_service_account" "lab10-service-account" {
  account_id   = "lab10-service-account"
  display_name = "lab10-service-account"
  description = "Service account for lab 10"
}

resource "google_service_account_iam_policy" "admin-acc-iam" {
  service_account_id = google_service_account.lab10-service-account.name
  policy_data        = data.google_iam_policy.admin.policy_data
}

resource "google_storage_bucket_iam_policy" "policy" {
  bucket      = google_storage_bucket.lab10-storage-bucket.name
  policy_data = data.google_iam_policy.bucket_policy.policy_data
}

// create storage bucket
resource "google_storage_bucket" "lab10-storage-bucket" {
  name = "lab10-storage-bucket"
  storage_class = "STANDARD"
  location = "us-west1"
}

output "external-ip" {
  value = google_compute_instance.vm-instance.network_interface[0].access_config[0].nat_ip
}
