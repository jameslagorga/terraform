
# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "gke-network"
  auto_create_subnetworks = false
  depends_on = [time_sleep.wait_for_api]
}

resource "time_sleep" "wait_for_api" {
    create_duration = "60s"
  depends_on = [google_project_service.compute]
}

# GKE Subnet
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet"
  ip_cidr_range = "10.10.0.0/24"
  network       = google_compute_network.vpc.self_link
  region        = "us-west1"
}

# Allocate an IP range for the service networking connection
# Note: You may need to adjust the prefix_length depending on your network requirements.
resource "google_compute_global_address" "vertex_ai_peering_range" {
  name          = "vertex-ai-peering-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  depends_on    = [google_project_service.servicenetworking]
}

# Create the VPC peering connection
resource "google_service_networking_connection" "vertex_ai_peering" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.vertex_ai_peering_range.name]
  depends_on              = [google_compute_global_address.vertex_ai_peering_range]
}
