terraform {
  required_version = ">= 1.3.0"

  required_providers {
    powerscale = {
      source  = "dell/powerscale"
      version = ">= 1.8.3, < 2.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.12.0, < 6.0.0"
    }
  }
}
