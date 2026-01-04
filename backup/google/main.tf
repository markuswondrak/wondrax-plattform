terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# --- VARIABLEN (Keine Defaults mehr!) ---
variable "project_id" {
  description = "Deine Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Region für den Bucket"
  type        = string
  default     = "europe-west3" # Default hier ok, kann aber überschrieben werden
}

variable "bucket_name" {
  description = "Global eindeutiger Name für den Bucket"
  type        = string
}

variable "sa_name" {
  description = "Name des Service Accounts"
  type        = string
  default     = "platform-backup-sa"
}

# --- PROVIDER ---
provider "google" {
  project = var.project_id
  region  = var.region
}

# --- 1. SERVICE ACCOUNT ---
resource "google_service_account" "backup_sa" {
  account_id   = var.sa_name
  display_name = "Service Account für Platform Backups"
}

# --- 2. STORAGE BUCKET ---
resource "google_storage_bucket" "backup_bucket" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = false 

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
  storage_class               = "STANDARD"
}

# --- 3. BERECHTIGUNGEN (IAM) ---
resource "google_storage_bucket_iam_member" "sa_bucket_access" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backup_sa.email}"
}

# --- 4. KEY GENERIERUNG ---
resource "google_service_account_key" "sa_key" {
  service_account_id = google_service_account.backup_sa.name
}

resource "local_file" "service_account_json" {
  content  = base64decode(google_service_account_key.sa_key.private_key)
  filename = "${path.module}/gcs-key.json"
}

# --- OUTPUT ---
output "bucket_url" {
  value = google_storage_bucket.backup_bucket.url
}