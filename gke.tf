
resource "google_container_cluster" "primary" {
  name     = "gke-cluster"
  location = "us-west1"

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.gke_subnet.name

  initial_node_count = 1

  node_config {
    disk_type = "pd-standard"
  }

  # Enable Filestore CSI driver
  addons_config {
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  depends_on = [google_project_service.gke]
}

resource "google_container_node_pool" "default_pool" {
  name           = "default-pool"
  location       = "us-west1"
  node_locations = ["us-west1-a"]
  cluster        = google_container_cluster.primary.name
  node_count     = 1
  version        = "1.33.5-gke.1201000"

  lifecycle {
    ignore_changes = [
      node_config[0].kubelet_config,
      node_config[0].resource_labels,
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = "e2-medium"
    disk_size_gb = 100
    disk_type    = "pd-standard"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      "node-pool-type" = "default-pool"
    }
  }
}


resource "google_container_node_pool" "gpu_pool_l4" {
  name           = "gpu-pool-l4"
  location       = "us-west1"
  node_locations = ["us-west1-a"]
  cluster        = google_container_cluster.primary.name
  node_count     = 1
  version        = "1.33.5-gke.1201000"

  lifecycle {
    ignore_changes = [
      node_config[0].kubelet_config,
      node_config[0].resource_labels,
      node_config[0].guest_accelerator,
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = "n1-standard-1"
    disk_size_gb = 100
    disk_type    = "pd-standard"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      "node-pool-type" = "gpu-pool-l4"
    }
  }
}
