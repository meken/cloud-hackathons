# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
resource "google_project_service" "default" {
  project = var.gcp_project_id
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "compute.googleapis.com",
    "aiplatform.googleapis.com",
    "composer.googleapis.com",
    "dataplex.googleapis.com",
    "datalineage.googleapis.com",
    "datacatalog.googleapis.com",
    "cloudaicompanion.googleapis.com"
  ])
    
  service = each.key

  disable_on_destroy = false
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

resource "google_compute_firewall" "fwr_allow_custom" {
  name          = "fwr-ingress-allow-custom"
  network       = google_compute_network.default_network_created[0].self_link
  count         = var.create_default_network ? 1 : 0
  source_ranges = ["10.128.0.0/9"]
  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "fwr_allow_iap" {
  name          = "fwr-ingress-allow-iap"
  network       = google_compute_network.default_network_created[0].self_link
  count         = var.create_default_network ? 1 : 0
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# This piece of code makes it possible to deal with the default network the same way, regardless of how it has
# been created. Make sure to refer to the default network through this resource when needed.
data "google_compute_network" "default_network" {
  name = "default"
  depends_on = [
    google_project_service.default,
    google_compute_network.default_network_created
  ]
}

resource "google_project_service_identity" "composer_default_sa" {
  provider = google-beta
  service  = "composer.googleapis.com"
}

resource "google_service_account" "dbt_sa" {
  account_id   = "sa-bqdwh-dbt"
  display_name = "BQ DWH DBT Service Account"
}

resource "google_service_account" "composer_sa" {
  account_id   = "sa-bqdwh-composer"
  display_name = "BQ DWH Composer Service Account"
}

resource "google_service_account" "startup_vm_sa" {
  account_id   = "sa-bqdwh-startup-vm"
  display_name = "BQ DWH Startup VM Service Account"
}

resource "google_project_iam_member" "composer_default_sa_roles" {
  project  = var.gcp_project_id
  for_each = toset([
    "roles/composer.serviceAgent"
  ])
  role   = each.key
  member = "serviceAccount:${google_project_service_identity.composer_default_sa.email}"
}


resource "google_project_iam_member" "dbt_sa_roles" {
  project = var.gcp_project_id
  for_each = toset([
    "roles/bigquery.user",
    "roles/bigquery.dataEditor",
    "roles/bigquery.connectionAdmin"
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.dbt_sa.email}"
}

resource "google_project_iam_member" "composer_sa_roles" {
  project = var.gcp_project_id
  for_each = toset([
    "roles/bigquery.admin",
    "roles/composer.worker"
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_project_iam_member" "startup_vm_sa_roles" {
  project = var.gcp_project_id
  for_each = toset([
    # TODO remove these roles
    # "roles/resourcemanager.projectIamAdmin",
    # "roles/bigquery.admin",
    ##########################
    "roles/composer.admin",
    "roles/storage.objectAdmin"
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.startup_vm_sa.email}"
}

resource "google_service_account_iam_member" "startup_vm_sa_using_composer_sa" {
  service_account_id = google_service_account.composer_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.startup_vm_sa.email}"
}

resource "google_storage_bucket" "landing_bucket" {
  name                        = "${var.gcp_project_id}-landing"
  location                    = var.gcp_region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "dags_bucket" {
  name                        = "${var.gcp_project_id}-dags"
  location                    = var.gcp_region
  uniform_bucket_level_access = true
}

resource "google_compute_instance" "startup_vm" {
  name         = "gce-lnx-env-setup"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm        = true
  }

  network_interface {
    network = data.google_compute_network.default_network.self_link
    access_config {}
  }

  service_account {
    email  = google_service_account.startup_vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/setup.tftpl", {
    gcp_project_id = var.gcp_project_id,
    gcp_region     = var.gcp_region,
    landing_bucket = google_storage_bucket.landing_bucket.name
    dags_bucket    = google_storage_bucket.dags_bucket.name
    composer_sa    = google_service_account.composer_sa.email
  })

  depends_on = [
    google_project_service.default,
    google_compute_network.default_network_created
  ]
}


