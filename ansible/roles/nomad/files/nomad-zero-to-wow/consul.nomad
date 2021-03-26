job "consul" {
    datacenters = ["West"]
    group "consul" {
        count = 1
        task "consul" {
            driver = "raw_exec"

            config {
                command = "consul"
                args    = ["agent", "-dev"]
            }

            artifact {
                source = "https://releases.hashicorp.com/consul/1.9.2/consul_1.9.2_linux_amd64.zip"
            }
        }
    }
}