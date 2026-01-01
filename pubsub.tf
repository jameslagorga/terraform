# Pub/Sub Topic for stereo vision processing
resource "google_pubsub_topic" "stereo_vision_topic" {
  name = "stereo-vision-topic"
  depends_on = [google_project_service.pubsub]
}

resource "google_pubsub_topic" "unpaired_stereo_images_topic" {
  name = "unpaired-stereo-images-topic"
  depends_on = [google_project_service.pubsub]
}

resource "google_pubsub_topic" "calibration_topic" {
  name = "calibration-topic"
  depends_on = [google_project_service.pubsub]
}

# Pub/Sub Subscription for the CREStereo workers
resource "google_pubsub_subscription" "crestereo_vision_subscription" {
  name  = "crestereo-vision-subscription"
  topic = google_pubsub_topic.stereo_vision_topic.name

  # 24 hours
  message_retention_duration = "86400s"
  # 60 seconds, allows for processing time and retries
  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "10s"
  }
  enable_message_ordering = false
  depends_on = [google_pubsub_topic.stereo_vision_topic]
}

# Pub/Sub Subscription for the Calibration server
resource "google_pubsub_subscription" "calibration_server_subscription" {
  name  = "calibration-server-subscription"
  topic = google_pubsub_topic.calibration_topic.name

  # 24 hours
  message_retention_duration = "86400s"
  # 60 seconds
  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "10s"
  }
  enable_message_ordering = false
  depends_on = [google_pubsub_topic.calibration_topic]
}
