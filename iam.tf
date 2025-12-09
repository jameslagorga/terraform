
# IAM Service Account for accessing the Filestore
resource "google_service_account" "filestore_accessor" {
  account_id   = "filestore-accessor"
  display_name = "Filestore Accessor"
}

# Grant the Filestore Editor role to the service account
resource "google_project_iam_member" "filestore_iam" {
  project = "binocular-cv"
  role    = "roles/file.editor"
  member  = "serviceAccount:${google_service_account.filestore_accessor.email}"
}

resource "google_project_iam_member" "lagorgeous_owner" {
  project = "binocular-cv"
  role    = "roles/owner"
  member  = "user:lagorgeous.creator@gmail.com"
}

resource "google_project_iam_member" "lagorgeous_cloudbuild_editor" {
  project = "binocular-cv"
  role    = "roles/cloudbuild.builds.editor"
  member  = "user:lagorgeous.creator@gmail.com"
}

data "google_project" "project" {}

resource "google_project_iam_member" "pubsub_publisher" {
  project = "binocular-cv"
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}
