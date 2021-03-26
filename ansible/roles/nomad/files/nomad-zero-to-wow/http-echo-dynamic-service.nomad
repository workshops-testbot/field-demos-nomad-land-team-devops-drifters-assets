job "http-echo-dynamic-service" {
  datacenters = ["West"]

  group "echo" {
    count = 5
    task "server" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:latest"
        args  = [
          "-listen", ":${NOMAD_PORT_http}",
          "-text", "Hello and welcome to ${NOMAD_IP_http} running on port ${NOMAD_PORT_http}",
        ]
      }

      resources {
        network {
          mbits = 10
          port "http" {}
        }
      }

      scaling "cpu" {
        policy {
          cooldown            = "1m"
          evaluation_interval = "1m"
          check "95pct" {
            strategy "app-sizing-percentile" {
              percentile = "95"
            }
          }
        }
      } # End scaling cpu

      scaling "mem" {
        policy {
          cooldown            = "1m"
          evaluation_interval = "1m"
          check "max" {
            strategy "app-sizing-max" {}
          }
        }
      } # End scaling mem


      service {
        name = "http-echo"
        port = "http"

        tags = [
          "macbook",
          "urlprefix-/http-echo",
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }
}