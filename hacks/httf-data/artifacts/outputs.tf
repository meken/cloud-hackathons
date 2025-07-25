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
output "project_id" {
  value = var.gcp_project_id
}

output "database_name" {
  value = google_sql_database_instance.mysql_source_db.name
}

output "database_user" {
  value = google_sql_user.sql_user.name
}

output "database_password" {
  value     = google_sql_user.sql_user.password
  sensitive = true
}
