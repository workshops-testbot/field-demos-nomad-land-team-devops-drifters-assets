job "hashicups" {
  # Deploy applications to multiple regions
  multiregion {
    strategy {
      max_parallel = 1
      on_failure   = "fail_all"
    }
    region "West" {
      count = 3
      datacenters = ["West"]
    }
    region "East" {
      count = 1
      datacenters = ["East"]
    }
  }

  # Define Nomad Scheduler to be used (Service/Batch/System)
  type     = "service"

  # Each component is defined within it's own Group
  group "postgres" {
    count = 1

    network {
      port "db" {
        static = 5432
      }
    }

    # Host volume on which to store Postgres Data.  Nomad will confirm the client offers the same volume for placement.
    volume "pgdata" {
      type      = "host"
      read_only = false
      source    = "pgdata"
    }

    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }

    #Actual Postgres task using the Docker Driver
    task "postgres" {
      driver = "docker"

      volume_mount {
        volume      = "pgdata"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }

      # Postgres Docker image location and configuration
      config {
        image = "hashicorpdemoapp/product-api-db:v0.0.15"
        dns_servers = ["172.17.0.1"]
        network_mode = "host"
        ports = ["db"]
      }

      # Task relevant environment variables necessary
      env {
          POSTGRES_USER="root"
          POSTGRES_PASSWORD="password"
          POSTGRES_DB="products"
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      # Host machine resources required
      resources {
        cpu = 300
        memory = 512
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

      # Service definition to be sent to Consul
      service {
        name = "postgres"
        port = "db"
        tags = ["postgres"]

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    } # end postgres task
  } # end postgres group

  # Products API component that interfaces with the Postgres database
  group "product-api" {
    count = 1

    network {
      port "http_port" {
        static = 9090
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "product-api" {
      driver = "docker"

      # Creation of the template file defining how the API will access the database
      template {
        destination   = "/secrets/db-creds"
        data = <<EOF
{
  "db_connection": "host=postgres.service.consul port=5432 user=root password=password dbname=products sslmode=disable",
  "bind_address": ":9090",
  "metrics_address": ":9103"
}
EOF
      }

      # Task relevant environment variables necessary
      env {
        CONFIG_FILE = "/secrets/db-creds"
      }

      # Product-api Docker image location and configuration
      config {
        image = "hashicorpdemoapp/product-api:v0.0.15"
        dns_servers = ["172.17.0.1"]
        ports = ["http_port"]
      }

      # Host machine resources required
      resources {
        cpu    = 100
        memory = 300
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

      # Service definition to be sent to Consul with corresponding health check
      service {
        name = "product-api-server"
        port = "http_port"
        tags = ["product-api"]
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    } # end product-api task
  } # end product-api group

  # Public API component
  group "public-api" {
    count = 1

    network {
      port "pub_api" {
        static = 9080
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    # Define update strategy for the Payments API
    update {
      canary  = 1
    }

    task "public-api" {
      driver = "docker"

      # Task relevant environment variables necessary
      env {
        BIND_ADDRESS = ":9080"
        PRODUCT_API_URI = "http://product-api-server.service.consul:9090"
        PAYMENT_API_URI = "http://payments-api-server.service.consul:8080"
      }

      # Public-api Docker image location and configuration
      config {
        image = "hashicorpdemoapp/public-api:v0.0.4"
        dns_servers = ["172.17.0.1"]
        ports = ["pub_api"]
      }

      # Host machine resources required
      resources {
        cpu    = 100
        memory = 256
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

      # Service definition to be sent to Consul with corresponding health check
      service {
        name = "public-api-server"
        port = "pub_api"
        tags = ["public-api"]
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  # Frontend component providing user access to the application
  group "frontend" {
    count = 0

    network {
      port "http" {
        static = 80
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "server" {
      driver = "docker"

      # Task relevant environment variables necessary
      env {
        PORT    = "${NOMAD_PORT_http}"
        NODE_IP = "${NOMAD_IP_http}"
      }

      # Frontend Docker image location and configuration
      config {
        image = "hashicorpdemoapp/frontend:v0.0.4"
        dns_servers = ["172.17.0.1"]
        volumes = [
          "local:/etc/nginx/conf.d",
        ]
        ports = ["http"]
      }

      # Creation of the NGINX configuration file
      template {
        data = <<EOF
resolver 172.17.0.1 valid=1s;
server {
    listen       80;
    server_name  localhost;
    set $upstream_endpoint public-api-server.service.consul;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
    # Proxy pass the api location to save CORS
    # Use location exposed by Consul connect
    location /api {
        proxy_pass http://$upstream_endpoint:9080;
        # Need the next 4 lines. Else browser might think X-site.
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
        destination   = "local/default.conf"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

      # Host machine resources required
      resources {
        cpu = 100
        memory = 256
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

      # Service definition to be sent to Consul with corresponding health check
      service {
        name = "frontend"
        port = "http"

        tags = ["frontend"]

        check {
          type     = "http"
          path     = "/"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }

  # Payment API component handles payments
  group "payments-api" {
    count = 1

    network {
      port "http_port" {
        static = 8080
      }
      dns {
        servers = ["172.17.0.1"]
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    # Define update strategy for the Payments API
    update {
      canary  = 1
    }

    # Service definition to be sent to Consul with corresponding health check
    service {
      name = "payments-api-server"
      port = "http_port"
      tags = ["payments-api"]
      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "payments-api" {
      driver = "java"
      
      vault {
        policies = [ "transform" ]
      }

      # Creation of the template file defining how the API will access the database
      template {
        destination   = "local/application.properties"
        data = <<EOF
app.storage=db
app.encryption.enabled=true
app.encryption.path=transform
app.encryption.key=payments
EOF
      }

      # Creation of the template file defining how to connect to vault
      template {
        destination   = "local/bootstrap.yml"
        data = <<EOF
spring:
  cloud:
    vault:
      enabled: true
      fail-fast: true
      authentication: TOKEN
      token: {{ env "VAULT_TOKEN" }}
      host: server-a-1
      port: 8200
      scheme: http
      kv:
        enabled: false
      generic:
        enabled: false
EOF
      }

      template {
        destination   = "local/application.yaml"
        data = <<EOF
spring:
  application:
    name: payments-api
  datasource:
    url: jdbc:h2:mem:testdb
    driverClassName: org.h2.Driver
    username: sa
    password: password
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    show-sql: true
  h2:
    console:
      enabled: true
      settings:
        web-allow-others: true
management:
  endpoint:
    health:
      show-details: always
EOF
      }

      # Task relevant environment variables necessary
      env {
        SPRING_CONFIG_LOCATION = "file:/local/"
        SPRING_CLOUD_BOOTSTRAP_LOCATION = "file:/local/"
      }

      # Product-api Docker image location and configuration
      config {
        jar_path    = "local/spring-boot-payments-0.0.11.jar"
        jvm_options = ["-Xmx1024m", "-Xms256m"]
      }

      artifact {
         source = "https://github.com/hashicorp-demoapp/payments/releases/download/v0.0.11/spring-boot-payments-0.0.11.jar"
      }

      # Host machine resources required
      resources {
        cpu    = 300
        memory = 512
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

    } # end payments-api task
  } # end payments-api group
}
