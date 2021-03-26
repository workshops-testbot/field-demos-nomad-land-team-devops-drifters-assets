job "webapp" {
  datacenters = ["West","West2"]
  group "webapp" {
    count = 6
    # spread {
    #   attribute = "${node.unique.name}"
    # }
    affinity {
      # attribute = "${attr.platform.gce.machine-type}"
      # value     = "n1-standard-2"
      attribute = "${node.datacenter}"
      value     = "West2"
      weight    = 100
    }
    network {
      port  "http" {}
    }
    task "server" {
      env {
        PORT    = "${NOMAD_PORT_http}"
        NODE_IP = "${NOMAD_IP_http}"
      }
      driver = "docker"
      config {
        image = "hashicorp/demo-webapp-lb-guide"
        ports = ["http"]
      }
      resources {
        cpu    = 20
        memory = 678
      }
      service {
        name = "webapp"
        port = "http"
        tags = [
          "traefik.tags=service",
          "traefik.frontend.rule=PathPrefixStrip:/myapp",
        ]
        check {
          type     = "http"
          path     = "/"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }
}