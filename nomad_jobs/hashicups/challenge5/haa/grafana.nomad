job "grafana" {
  datacenters = ["West"]

  group "grafana" {
    count = 1

    # # Create a host volume
    # volume "grafana" {
    #   type   = "host"
    #   source = "grafana"
    # }

    task "grafana" {
      driver = "docker"

      config {
        # Specify docker image
        image = "grafana/grafana:7.0.0"

        # Map network port.
        port_map {
          grafana_ui = 3000
        }

        # Mount docker volumes. First two
        volumes = [
          "local/datasources:/etc/grafana/provisioning/datasources",
          "local/dashboards:/etc/grafana/provisioning/dashboards",
          # "/root/nomad_jobs/hashicups/challenge5/files:/var/lib/grafana/dashboards",
        ]
      }

      env {
        GF_AUTH_ANONYMOUS_ENABLED  = "true"
        GF_AUTH_ANONYMOUS_ORG_ROLE = "Editor"
      }

      template {
        data = <<EOH
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  url: http://{{ range $i, $s := service "prometheus" }}{{ if eq $i 0 }}{{.Address}}:{{.Port}}{{end}}{{end}}
  isDefault: true
  version: 1
  editable: false
EOH

        destination = "local/datasources/prometheus.yaml"
      }

      template {
        data = <<EOH
apiVersion: 1
datasources:
- name: Loki
  type: loki
  access: proxy
  url: http://{{ range $i, $s := service "loki" }}{{ if eq $i 0 }}{{.Address}}:{{.Port}}{{end}}{{end}}
  isDefault: false
  version: 1
  editable: false
EOH

        destination = "local/datasources/loki.yaml"
      }

      template {
        data = <<EOH
apiVersion: 1

providers:
- name: Nomad Autoscaler
  folder: Nomad
  folderUid: nomad
  type: file
  disableDeletion: true
  editable: false
  allowUiUpdates: false
  options:
    path: /var/lib/grafana/dashboards
EOH

        destination = "local/dashboards/nomad-autoscaler.yaml"
      }

      # volume_mount {
      #   volume      = "grafana"
      #   destination = "/var/lib/grafana"
      # }

      resources {
        cpu    = 100
        memory = 64

        network {
          mbits = 10

          port "grafana_ui" {
            static = 3000
          }
        }
      } # end resources
      service {
        name = "grafana"
        port = "grafana_ui"
        check {
          type     = "http"
          path     = "/"
          interval = "3s"
          timeout  = "1s"
        }
      } # end service
    } # end task
  } # end group
} # end job
