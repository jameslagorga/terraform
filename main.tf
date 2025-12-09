terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    time = {
      source = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

provider "google" {
  project = "binocular-cv"
  region  = "us-west1"
}

# Enable necessary APIs
resource "google_project_service" "gke" {
  service = "container.googleapis.com"
}

resource "google_project_service" "filestore" {
  service = "file.googleapis.com"
}

resource "google_project_service" "pubsub" {
  service = "pubsub.googleapis.com"
}

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "monitoring" {
  service = "monitoring.googleapis.com"
}

resource "google_project_service" "servicenetworking" {
  service = "servicenetworking.googleapis.com"
  depends_on = [google_project_service.compute]
}








resource "google_compute_address" "nginx_static_ip" {
  name = "nginx-static-ip"
}

# Outputs
output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "gke_cluster_region" {
  value = google_container_cluster.primary.location
}

output "filestore_ip_address" {
  value = google_filestore_instance.nfs_store.networks[0].ip_addresses[0]
}

output "filestore_file_share_name" {
  value = google_filestore_instance.nfs_store.file_shares[0].name
}


