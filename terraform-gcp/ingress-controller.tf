################## Ingress ###############
resource "kubernetes_ingress_v1" "terra-ingress" {
  metadata {
    name = "terra-ingress"
    annotations = {
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.default.address
      "ingress.gcp.kubernetes.io/pre-shared-cert" = "nginx-terraform"
      "kubernetes.io/ingress.class" =  "gce"
    }
  }

  spec {
    rule {
      host = var.nginx
      http {
        path {
          backend {
            service {
              name = "nginx"
              port {
              number = 80
            }
            }
          }

          path = "/"
        }

      }
    } 
  }
}
