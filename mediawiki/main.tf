/*
William Hanson
Cabrillo College, CIS91, Fall 2022
Assignment: Project 3
12/12/2022
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

variable "num_instances" {
  default = 3
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


# Database server
resource "google_compute_instance" "vm_db" {
  name         = "db"
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
    source = google_compute_disk.project3-persistent-db.self_link
    device_name = "project3-persistent-db"
  }
  service_account {
    email  = google_service_account.project3-service-account.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_disk" "project3-persistent-db" {
  name  = "project3-persistent-db"
  type  = "pd-ssd"
  labels = {
    environment = "project3"
  }
  size = "100"
}


# Webserver instances
resource "google_compute_instance" "webservers" {
  count = var.num_instances
  name         = "web${count.index}"
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
  
  labels = {
    role: "web"
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


data "google_iam_policy" "admin" {
  binding {
    role = "roles/iam.serviceAccountAdmin"
    members = [
      "serviceAccount:${google_service_account.project3-service-account.email}",
    ]
  }
}

resource "google_service_account" "project3-service-account" {
  account_id   = "project3-service-account"
  display_name = "project3-service-account"
  description = "Service account for Project 3"
}

resource "google_service_account_iam_policy" "admin-acc-iam" {
  service_account_id = google_service_account.project3-service-account.name
  policy_data        = data.google_iam_policy.admin.policy_data
}



# Health check
resource "google_compute_health_check" "webservers" {
  name = "webserver-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port = 80
  }
}

# Instance Group
resource "google_compute_instance_group" "webservers" {
  name        = "cis91-webservers"
  description = "Webserver instance group"

  instances = google_compute_instance.webservers[*].self_link

  named_port {
    name = "http"
    port = "80"
  }
}

# Backend Service
resource "google_compute_backend_service" "webservice" {
  name      = "web-service"
  port_name = "http"
  protocol  = "HTTP"

  backend {
    group = google_compute_instance_group.webservers.id
  }

  health_checks = [
    google_compute_health_check.webservers.id
  ]
}

# URL Map: Everything to our one service
resource "google_compute_url_map" "default" {
  name            = "my-site"
  default_service = google_compute_backend_service.webservice.id
}

# Proxy
resource "google_compute_target_http_proxy" "default" {
  name     = "web-proxy"
  url_map  = google_compute_url_map.default.id
}

# External IP address
resource "google_compute_global_address" "default" {
  name = "external-address"
}

# Forwarding rule
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "forward-application"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
  ip_address            = google_compute_global_address.default.address
}

output "external-ip" {
  value = google_compute_instance.webservers[*].network_interface[0].access_config[0].nat_ip
}

output "lb-ip" {
  value = google_compute_global_address.default.address
}

