
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

resource "google_storage_bucket" "standard_storage_bucket" {
  name          = "binocular-cv-standard"
  location      = "US-WEST1"
  storage_class = "STANDARD"
}
