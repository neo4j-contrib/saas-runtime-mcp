// main.tf

// -----------------------------------------------------------------------------
// INPUT VARIABLES
// -----------------------------------------------------------------------------

variable "gcp_project_id" {
  description = "The Google Cloud project ID where resources will be created."
  type        = string
  default = "saas-runtime-mcp"
}

variable "gcp_region" {
  description = "The Google Cloud region for deploying the Cloud Run service."
  type        = string
  default     = "us-central1"
}

variable "tools_yaml_secret_name" {
  description = "The name of the secret in Secret Manager for tools.yaml."
  type        = string
  default     = "tools"
}

variable "cloud_run_service_account_id" {
  description = "The ID (name part) of the service account for Cloud Run (e.g., 'toolbox-identity')."
  type        = string
  default     = "toolbox-identity"
}

// Configure the Google Cloud provider
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

// -----------------------------------------------------------------------------
// RESOURCES
// -----------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "mcp_toolbox_service" {
  deletion_protection = false
  name     = "toolbox5"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = "${var.cloud_run_service_account_id}@${var.gcp_project_id}.iam.gserviceaccount.com"

    containers {
      image = "us-central1-docker.pkg.dev/database-toolbox/toolbox/toolbox:latest"
      ports {
        container_port = 8080
      }

      args = [
        "--tools-file=tools.yaml", 
        "--address=0.0.0.0",
        "--port=8080"
      ]

      volume_mounts {
        name       = "tools-config-volume"
        mount_path = "/app"
      }
    }

    // Define the volume that sources data from Secret Manager
    volumes {
      name = "tools-config-volume"
      secret {
        secret = var.tools_yaml_secret_name
        items {
          version = "latest"
          path    = "tools.yaml"
        }
      }
    }
    vpc_access {
      network_interfaces {
        network    = "default"
        subnetwork = "default"
      }
      egress = "ALL_TRAFFIC"
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "allow_unauthenticated" {
  project  = google_cloud_run_v2_service.mcp_toolbox_service.project
  location = google_cloud_run_v2_service.mcp_toolbox_service.location
  name     = google_cloud_run_v2_service.mcp_toolbox_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [google_cloud_run_v2_service.mcp_toolbox_service]
}

// -----------------------------------------------------------------------------
// OUTPUTS
// -----------------------------------------------------------------------------

output "mcp_toolbox_service_url" {
  description = "The URL of the deployed MCP Toolbox Cloud Run service."
  value       = google_cloud_run_v2_service.mcp_toolbox_service.uri
}

output "cloud_run_service_account_used" {
  description = "The full email of the service account used by the Cloud Run service."
  value       = google_cloud_run_v2_service.mcp_toolbox_service.template[0].service_account
}
