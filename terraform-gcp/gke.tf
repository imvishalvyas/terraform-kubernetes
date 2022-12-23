########################################## Variables ########################################################
variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}

variable "zone" {
  default     = ""
  description = "zone"
}

variable "host" {
  default     = ""
  description = "host"
}

variable "client_certificate" {
  default     = ""
  description = "client_certificate"
}

variable "client_key" {
  default     = ""
  description = "client_key"
}

variable "cluster_ca_certificate" {
  default     = ""
  description = "cluster_ca_certificate"
}


######################################### Providers #########################################################
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.27.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
  required_version = ">= 0.14"
}


###################################### Add Modules here #####################################################

module "deployments" {
  source   = "./deployments"
}

module "nginx" {
  source   = "./deployments/nginx"
}


############################# GKE Create Cluster and Node Pool ##############################################
resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-gke"
  location = var.zone
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    preemptible  = true
    disk_size_gb = 10
    machine_type = "e2-micro"
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

################################ GKE Authentication #########################################################
module "gke_auth" {
  source               = "terraform-google-modules/kubernetes-engine/google//modules/auth"

  project_id           = var.project_id
  cluster_name         = google_container_cluster.primary.name
  location             = var.zone
}

provider "kubernetes" {
  cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
  host                   = module.gke_auth.host
  token                  = module.gke_auth.token
}


############################## GCP Static IP for Ingress ####################################################
resource "google_compute_global_address" "default" {
  name = "terraip"
}


################################ SSl Certificates ###########################################################
resource "google_compute_managed_ssl_certificate" "nginx" {
  name    = "nginx-terraform"
  project = var.project_id

  managed {
    domains = [var.nginx]
  }
}


###################### kube config #############################################
resource "local_file" "kubeconfig" {
  content  = module.gke_auth.kubeconfig_raw
  filename = "${path.module}/kubeconfig"

}

