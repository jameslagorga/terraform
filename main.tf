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
  # Replace with your GCP project ID
  project = "lagorgeous-helping-hands"
  # The region for the resources
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

resource "time_sleep" "wait_for_api" {
    create_duration = "60s"
  depends_on = [google_project_service.compute]
}

# Pub/Sub Topic for frame processing
resource "google_pubsub_topic" "frame_processing_topic" {
  name = "frame-processing-topic"
  depends_on = [google_project_service.pubsub]
}

# Pub/Sub Subscription for the hand-finder workers
resource "google_pubsub_subscription" "hand_finder_subscription" {
  name  = "hand-finder-subscription"
  topic = google_pubsub_topic.frame_processing_topic.name

  # 24 hours
  message_retention_duration = "86400s"
  # 20 seconds, allows for processing time and retries
  ack_deadline_seconds = 20

  retry_policy {
    minimum_backoff = "10s"
  }
  enable_message_ordering = false
  depends_on = [google_pubsub_topic.frame_processing_topic]
}

# Pub/Sub Subscription for the hamer-infer workers
resource "google_pubsub_subscription" "hamer_infer_subscription" {
  name  = "hamer-infer-subscription"
  topic = google_pubsub_topic.frame_processing_topic.name

  # 24 hours
  message_retention_duration = "86400s"
  # 60 seconds, allows for processing time and retries
  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "10s"
  }
  enable_message_ordering = false
  depends_on = [google_pubsub_topic.frame_processing_topic]
}

# Pub/Sub Subscription for the yolo-hand-pose workers
resource "google_pubsub_subscription" "yolo_hand_pose_subscription" {
  name  = "yolo-hand-pose-subscription"
  topic = google_pubsub_topic.frame_processing_topic.name

  # 24 hours
  message_retention_duration = "86400s"
  # 60 seconds, allows for processing time and retries
  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "10s"
  }
  enable_message_ordering = false
  depends_on = [google_pubsub_topic.frame_processing_topic]
}

# Pub/Sub Subscription for the hamer-hand-counter workers
resource "google_pubsub_subscription" "hamer_hand_counter_subscription" {
  name  = "hamer-hand-counter-subscription"
  topic = google_pubsub_topic.frame_processing_topic.name

  # 24 hours
  message_retention_duration = "86400s"
  # 60 seconds, allows for processing time and retries
  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "10s"
  }
  enable_message_ordering = false
  depends_on = [google_pubsub_topic.frame_processing_topic]
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "gke-network"
  auto_create_subnetworks = false
  depends_on = [time_sleep.wait_for_api]
}

# GKE Subnet
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet"
  ip_cidr_range = "10.10.0.0/24"
  network       = google_compute_network.vpc.self_link
  region        = "us-west1"
}

# Enable the Service Networking API
resource "google_project_service" "servicenetworking" {
  service = "servicenetworking.googleapis.com"
  depends_on = [google_project_service.compute]
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

  # We need to create a node pool to run workloads
  remove_default_node_pool = true

  depends_on = [google_project_service.gke]
}

resource "google_container_node_pool" "default_pool" {
  name           = "default-pool"
  location       = "us-west1"
  node_locations = ["us-west1-a"]
  cluster        = google_container_cluster.primary.name
  node_count     = 1
  version        = var.node_version

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


resource "google_container_node_pool" "gpu_pool" {
  name           = "gpu-pool"
  location       = "us-west1"
  node_locations = ["us-west1-a"]
  cluster        = google_container_cluster.primary.name
  node_count     = 1
  version        = var.node_version

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
    machine_type = "g2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-standard"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      "node-pool-type" = "gpu-pool"
    }

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
    }
  }
}

resource "google_container_node_pool" "recorder-pool" {
  name           = "recorder-pool"
  location       = "us-west1"
  node_locations = ["us-west1-a"]
  cluster        = google_container_cluster.primary.name
  node_count     = 1
  version        = var.node_version

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
    machine_type = "e2-standard-16"
    disk_size_gb = 100
    disk_type    = "pd-standard"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      "node-pool-type" = "recorder-pool"
    }
  }
}

# Filestore Instance
resource "google_filestore_instance" "nfs_store" {
  name     = "nfs-store"
  location = "us-west1-a" # Must be a zone
  tier     = "STANDARD"

  file_shares {
    capacity_gb = 5120
    name        = "fileshare"
  }

  networks {
    network = google_compute_network.vpc.name
    modes   = ["MODE_IPV4"]
  }

  depends_on = [google_project_service.filestore]
}

# IAM Service Account for accessing the Filestore
resource "google_service_account" "filestore_accessor" {
  account_id   = "filestore-accessor"
  display_name = "Filestore Accessor"
}

# Grant the Filestore Editor role to the service account
resource "google_project_iam_member" "filestore_iam" {
  project = "lagorgeous-helping-hands"
  role    = "roles/file.editor"
  member  = "serviceAccount:${google_service_account.filestore_accessor.email}"
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

resource "google_storage_bucket" "standard_storage_bucket" {
  name          = "lagorgeous-helping-hands-standard"
  location      = "US-WEST1"
  storage_class = "STANDARD"
}

output "standard_storage_bucket_name" {
  value = google_storage_bucket.standard_storage_bucket.name
}

resource "google_project_iam_member" "lagorgeous_owner" {
  project = "lagorgeous-helping-hands"
  role    = "roles/owner"
  member  = "user:lagorgeous.creator@gmail.com"
}

resource "google_project_iam_member" "lagorgeous_cloudbuild_editor" {
  project = "lagorgeous-helping-hands"
  role    = "roles/cloudbuild.builds.editor"
  member  = "user:lagorgeous.creator@gmail.com"
}



resource "google_project_iam_member" "perberto_cloudbuild_editor" {
  project = "lagorgeous-helping-hands"
  role    = "roles/cloudbuild.builds.editor"
  member  = "user:perbhatk@gmail.com"
}

resource "google_monitoring_dashboard" "pubsub_dashboard" {
  project = "lagorgeous-helping-hands"
  dashboard_json = <<EOF
{
  "displayName": "Pub/Sub Frame Processing",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "Publish Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"pubsub.googleapis.com/topic/send_request_count\" resource.type=\"pubsub_topic\" resource.label.\"topic_id\"=\"frame-processing-topic\"",
                  "aggregation": {
                    "perSeriesAligner": "ALIGN_RATE",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": []
                  }
                },
                "unitOverride": "1/s"
              },
              "plotType": "LINE"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Messages per second",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Hand Finder Message Read Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"pubsub.googleapis.com/subscription/ack_message_count\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"hand-finder-subscription\"",
                  "aggregation": {
                    "perSeriesAligner": "ALIGN_RATE",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": []
                  }
                },
                "unitOverride": "1/s"
              },
              "plotType": "LINE"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Messages per second",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "HaMeR Message Read Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"pubsub.googleapis.com/subscription/ack_message_count\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"hamer-infer-subscription\"",
                  "aggregation": {
                    "perSeriesAligner": "ALIGN_RATE",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": []
                  }
                },
                "unitOverride": "1/s"
              },
              "plotType": "LINE"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Messages per second",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "YOLO Hand Pose Message Read Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"pubsub.googleapis.com/subscription/ack_message_count\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"yolo-hand-pose-subscription\"",
                  "aggregation": {
                    "perSeriesAligner": "ALIGN_RATE",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": []
                  }
                },
                "unitOverride": "1/s"
              },
              "plotType": "LINE"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Messages per second",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "HaMeR Hand Counter Message Read Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"pubsub.googleapis.com/subscription/ack_message_count\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"hamer-hand-counter-subscription\"",
                  "aggregation": {
                    "perSeriesAligner": "ALIGN_RATE",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": []
                  }
                },
                "unitOverride": "1/s"
              },
              "plotType": "LINE"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Messages per second",
            "scale": "LINEAR"
          }
        }
      }
    ]
  }
}
EOF
}

data "google_project" "project" {}

resource "google_project_iam_member" "pubsub_publisher" {
  project = "lagorgeous-helping-hands"
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}
