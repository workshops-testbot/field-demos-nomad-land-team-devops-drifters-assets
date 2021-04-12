terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "pphan"

    workspaces {
      name = "nomad_jobs"
    }
  }
}