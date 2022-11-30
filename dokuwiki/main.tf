/*
William Hanson
Cabrillo College, CIS-91, Fall 2022
Assignment: Project2-dokuwiki
11/22/2022
*/

variable "credentials_file" { 
  default = "/home/wil9640/cis-91-360404-0fc83fe160a0.json" 
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

variable "instance_type" {
  default = "e2-micro"
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
  name         = "dokuwiki"
  machine_type = var.instance_type

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  
  attached_disk {
    source = google_compute_disk.dokuwiki-persistent.self_link
    device_name = "dokuwiki-persistent"
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

resource "google_compute_firewall" "default-firewall" {
  name = "default-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22", "80"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_disk" "dokuwiki-persistent" {
  name  = "dokuwiki-persistent"
  type  = "pd-ssd"
  labels = {
    environment = "dokuwiki"
  }
  size = "100"
}

data "google_iam_policy" "admin" {
  binding {
    role = "roles/iam.serviceAccountAdmin"
    members = [
      "serviceAccount:${google_service_account.dokuwiki-service-account.email}",
    ]
  }
}

data "google_iam_policy" "bucket_policy" {
  binding {
    role = "roles/storage.admin"
    members = [
      "serviceAccount:${google_service_account.dokuwiki-service-account.email}",
      "user:william_hanson@hotmail.com",
    ]
  }
}

resource "google_service_account" "dokuwiki-service-account" {
  account_id   = "dokuwiki-service-account"
  display_name = "dokuwiki-service-account"
  description = "Service account for Dokuwiki"
}

resource "google_service_account_iam_policy" "admin-acc-iam" {
  service_account_id = google_service_account.dokuwiki-service-account.name
  policy_data        = data.google_iam_policy.admin.policy_data
}

resource "google_storage_bucket_iam_policy" "policy" {
  bucket      = google_storage_bucket.dokuwiki-storage-bucket.name
  policy_data = data.google_iam_policy.bucket_policy.policy_data
}

// create storage bucket
resource "google_storage_bucket" "dokuwiki-storage-bucket" {
  name = "dokuwiki-storage-bucket"
  storage_class = "STANDARD"
  location = "us-west1"
}
output "external-ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}
