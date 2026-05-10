terraform {
  required_version = ">= 1.6"

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.11"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}
