provider "powerscale" {
  endpoint = var.powerscale_endpoint
  username = var.powerscale_username
  password = var.powerscale_password
}

provider "vault" {
  address = var.vault_address
}
