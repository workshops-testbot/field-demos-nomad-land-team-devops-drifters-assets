# For full documentation and examples, see
#     https://www.nomadproject.io/docs/job-specification/job.html
job "vault" {
  # datacenters = ["eu-west-2","ukwest","sa-east-1","ap-northeast-1","dc1"]
  datacenters = ["West"]
  type = "service"

  group "vault-primary" {
    count = 3
    task "vault-enterprise" {
      driver = "docker"
      config {
        image = "hashicorp/vault-enterprise:latest"
        command = "vault"
        args = [
          "server", "-config=/vault/config",
        ]
        # cap_add = [
        #   "IPC_LOCK",
        # ]
        volumes = [
          "local/file:/vault/file",
          "local/config:/vault/config",
        ]
        port_map {
          http = 8200
        }
      }
      env {
        VAULT_ADDR="http://127.0.0.1:8200"
      }
      template {
        data = <<EOF
# Full configuration options can be found at https://www.vaultproject.io/docs/configuration

api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
ui = true
#mlock = true
disable_mlock = true

# Storage - File
storage "file" { path = "/vault/file" }

# Storage - Integrated Storage
#storage "raft" {
#  path    = "/opt/vault/data"
#  node_id = "server-a-1"
#}

# Storage - Consul
#storage "consul" {
#  address = "127.0.0.1:8500"
#  path    = "vault"
#}

# HTTP listener
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

# HTTPS listener
# listener "tcp" {
#   address       = "0.0.0.0:8200"
#   tls_cert_file = "/opt/vault/tls/tls.crt"
#   tls_key_file  = "/opt/vault/tls/tls.key"
# }

# Example AWS KMS auto unseal
#seal "awskms" {
#  region = "us-east-1"
#  kms_key_id = "REPLACE-ME"
#}

# Example HSM auto unseal
#seal "pkcs11" {
#  lib            = "/usr/vault/lib/libCryptoki2_64.so"
#  slot           = "0"
#  pin            = "AAAA-BBBB-CCCC-DDDD"
#  key_label      = "vault-hsm-key"
#  hmac_key_label = "vault-hsm-hmac-key"
#}
EOF

        destination   = "local/config/vault.hcl"
        change_mode   = "signal"
        change_signal = "SIGUSR1"
      } # end template
      logs {
        max_files     = 5
        max_file_size = 35
      }
      resources {
        network {
          port  "http"  {
            static = 8200
          }
        }
      }
      service {
        name = "vault-primary"
        tags = ["urlprefix-/vault-docker-primary strip=/vault-docker-primary"]
        port = "http"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }
  }
  update {
    max_parallel = 1
    min_healthy_time = "5s"
    healthy_deadline = "3m"
    auto_revert = false
    canary = 0
  }
}
