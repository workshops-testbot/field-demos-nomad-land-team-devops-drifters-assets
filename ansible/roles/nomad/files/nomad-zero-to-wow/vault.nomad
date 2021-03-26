job "vault" {
    datacenters = ["West"]
    group "vault" {
        count = 1
        task "vault" {
            driver = "raw_exec"

            config {
                command = "vault"
                args    = ["server", "-dev", "-dev-root-token-id=root", "-dev-listen-address=0.0.0.0:9200"]
            }

            artifact {
                source = "https://releases.hashicorp.com/vault/1.6.2/vault_1.6.2_linux_amd64.zip"
            }
        }
    }
}