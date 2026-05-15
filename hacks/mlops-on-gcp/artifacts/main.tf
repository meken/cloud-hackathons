terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.24.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "7.24.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

resource "google_project_service" "default" {
  project = var.gcp_project_id
  for_each = toset([
    "compute.googleapis.com",
    "notebooks.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudbuild.googleapis.com",
    "sourcerepo.googleapis.com",
    "cloudscheduler.googleapis.com",
    "pubsub.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com"
  ])
  service = each.key

  disable_on_destroy = false
}

data "google_project" "project" {
  depends_on = [
    google_project_service.default
  ]
}

resource "google_service_account" "mlops_build_sa" {
  account_id   = "sa-mlops-build"
  display_name = "MLOps Build Service Account"
  project      = var.gcp_project_id
  depends_on = [
    google_project_service.default
  ]
}

resource "google_service_account" "mlops_kfp_sa" {
  account_id   = "sa-mlops-kfp"
  display_name = "Kubeflow Pipelines Service Account"
  project      = var.gcp_project_id
  depends_on = [
    google_project_service.default
  ]
}

# In case a default network is not present in the project the variable `create_default_network` needs to be set.
resource "google_compute_network" "default_network_created" {
  name                    = "default"
  auto_create_subnetworks = true
  count                   = var.create_default_network ? 1 : 0
  depends_on = [
    google_project_service.default
  ]
}

resource "google_compute_firewall" "default_allow_custom_created" {
  name          = "default-allow-custom"
  network       = google_compute_network.default_network_created[0].self_link
  count         = var.create_default_network ? 1 : 0
  source_ranges = ["10.128.0.0/9"]
  allow {
    protocol = "all"
  }
}

# This piece of code makes it possible to deal with the default network the same way, regardless of how it has
# been created. Make sure to refer to the default network through this resource when needed.
data "google_compute_network" "default_network" {
  name       = "default"
  depends_on = [
    google_compute_network.default_network_created
  ]
}

resource "google_project_iam_member" "mlops_build_sa_iam" {
  project = var.gcp_project_id
  for_each = toset([
    "roles/aiplatform.admin",
    "roles/storage.objectAdmin",
    "roles/source.reader",
    "roles/logging.logWriter"
  ])
  role   = each.key
  member = google_service_account.mlops_build_sa.member
  depends_on = [
    google_project_service.default
  ]
}

resource "google_project_iam_member" "mlops_kfp_sa_iam" {
  project = var.gcp_project_id
  for_each = toset([
    "roles/bigquery.admin",
    "roles/aiplatform.admin",
    "roles/storage.admin",
    "roles/monitoring.notificationChannelViewer"
  ])
  role   = each.key
  member = google_service_account.mlops_kfp_sa.member
  depends_on = [
    google_project_service.default
  ]
}

resource "google_project_service_identity" "monitoring_default_sa" {
  provider = google-beta

  project = data.google_project.project.project_id
  service = "monitoring.googleapis.com"
}

resource "google_project_iam_member" "monitoring_default_iam" {
  project = var.gcp_project_id
  for_each = toset([
    "roles/pubsub.publisher",
    "roles/monitoring.notificationServiceAgent"
  ])
  role   = each.key
  member = google_project_service_identity.monitoring_default_sa.member
  depends_on = [
    google_project_service.default
  ]
}

resource "google_project_service_identity" "cloudbuild_sa" {
  provider = google-beta

  project = data.google_project.project.project_id
  service = "cloudbuild.googleapis.com"
  depends_on = [
    google_project_service.default
  ]
}

resource "google_project_iam_member" "cloudbuild_sa_pubsub" {
  project = var.gcp_project_id
  role    = "roles/pubsub.subscriber"
  member  = google_project_service_identity.cloudbuild_sa.member
  depends_on = [
    google_project_service.default
  ]
}

resource "google_service_account_iam_member" "mlops_build_use_mlops_kfp" {
  service_account_id = google_service_account.mlops_kfp_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.mlops_build_sa.member
}

# This is an optional resource in case participants want to try it out as an alternative way to manage their
# templates
resource "google_artifact_registry_repository" "kfp_artifacts" {
  location      = var.gcp_region
  repository_id = "kfp-artifacts"
  description   = "Repository for Kubeflow Pipelines templates"
  format        = "KFP"
  depends_on = [
    google_project_service.default
  ]
}
