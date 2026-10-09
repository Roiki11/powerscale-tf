module "powerscale_s3" {
  source = "./modules/powerscale-s3"

  zone              = var.zone
  users             = var.users
  user_passwords    = var.user_passwords
  vault_mount       = var.vault_mount
  vault_path_prefix = var.vault_path_prefix
}
