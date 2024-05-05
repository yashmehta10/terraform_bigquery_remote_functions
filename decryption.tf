locals {
  cloud_function_config = {
    "remote_function_archive_name" = "remote_function_code.zip"
  }
  bigquery_function_config = {
    "bigquery_function_name"           = "base64_decrypt"
    "bigquery_function_max_batch_size" = 1000
  }

}

# Enable required APIs
resource "google_project_service" "cloud_function_api" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service" "cloud_build_api" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "bigquery_connection_api" {
  project = var.project_id
  service = "bigqueryconnection.googleapis.com"
}

# Bucket to hold cloud function zip file
resource "google_storage_bucket" "remote_function_bucket" {
  name          = "remote_function-${var.project_id}"
  force_destroy = true
  location      = var.location
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}

# Zip local file
data "archive_file" "zip_remote_function_code" {
  type        = "zip"
  output_path = "./application/${local.cloud_function_config.remote_function_archive_name}" # Location of the zipped file
  source_dir  = "./application/cloud_function/bq_base64_decrypt/"                               # Location of the source code
}

# Generate a new id each time code changes
resource "random_id" "random_id" {
  keepers = {
    zip_sha = data.archive_file.zip_remote_function_code.output_sha256
  }
  byte_length = 8
}

# Upload zip file to GCS
resource "google_storage_bucket_object" "remote_function_gcs_object" {
  name   = "${local.cloud_function_config.remote_function_archive_name}-${random_id.random_id.hex}"
  bucket = google_storage_bucket.remote_function_bucket.name
  source = data.archive_file.zip_remote_function_code.output_path
}

# Cloud function definition 
resource "google_cloudfunctions_function" "function" {
  name        = "remote_function_${local.bigquery_function_config.bigquery_function_name}"
  description = "Decrypt base 64 data"
  runtime     = "python39"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.remote_function_bucket.name
  source_archive_object = google_storage_bucket_object.remote_function_gcs_object.name
  trigger_http          = true
  entry_point           = "accept_request"

  depends_on = [
    google_project_service.cloud_function_api
  ]
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

# BigQuery dataset to hold the functions
resource "google_bigquery_dataset" "remote_function_dataset" {
  dataset_id    = "remote_function_dataset"
  friendly_name = "remote_function_dataset"
  description   = "Dataset to hold remote functions"
  location      = var.location
}

# Create external connection for BigQuery 
resource "google_bigquery_connection" "main" {
  connection_id = "remote_function_connection"
  project       = var.project_id
  location      = var.location
  cloud_resource {}
}

resource "google_bigquery_job" "job" {
  job_id     = "job_query_${formatdate("YYYY_MM_DD_hh_mm_ss", timestamp())}"
  location = var.location

  query {
    query = <<EOT
      CREATE OR REPLACE FUNCTION `${var.project_id}.${google_bigquery_dataset.remote_function_dataset.dataset_id}.base64_decrypt`(x STRING) RETURNS STRING
      REMOTE WITH CONNECTION `${var.project_id}.${var.location}.${split("/", google_bigquery_connection.main.name)[5]}`
      OPTIONS (
        endpoint = '${google_cloudfunctions_function.function.https_trigger_url}',
        max_batching_rows = ${local.bigquery_function_config.bigquery_function_max_batch_size}
      )
    EOT
    create_disposition = ""
    write_disposition = ""
  }
}

# Grant connection Service Account Cloud Function invoker role
resource "google_cloudfunctions_function_iam_member" "remote_function_connection_invoker" {
  project        = var.project_id
  region         = var.location
  cloud_function = google_cloudfunctions_function.function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_bigquery_connection.main.cloud_resource[0].service_account_id}"
}