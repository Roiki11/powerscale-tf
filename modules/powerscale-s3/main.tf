locals {
  buckets = {
    for bucket in flatten([
      for username, user in var.users : [
        for bucket_name, definition in user.buckets : {
          key         = "${username}/${bucket_name}"
          username    = username
          name        = bucket_name
          path        = definition.path
          create_path = definition.create_path
          description = definition.description
          acl         = definition.acl
        }
      ]
    ]) : bucket.key => bucket
  }

  vault_path_prefix = trim(trimspace(var.vault_path_prefix), "/")
}

resource "powerscale_user" "s3_user" {
  for_each = var.users

  name           = each.key
  query_zone     = var.zone
  uid            = each.value.uid
  email          = each.value.email
  password       = lookup(var.user_passwords, each.key, null)
  home_directory = "/ifs/data/${each.key}"
  shell          = "/bin/nologin"
}

resource "powerscale_s3_bucket" "bucket" {
  for_each = local.buckets

  name        = each.value.name
  path        = each.value.path
  create_path = each.value.create_path
  description = each.value.description
  owner       = powerscale_user.s3_user[each.value.username].name
  zone        = var.zone
  acl         = each.value.acl
}

resource "powerscale_s3_key" "user_key" {
  for_each = var.users

  user                     = powerscale_user.s3_user[each.key].name
  zone                     = var.zone
  existing_key_expiry_time = each.value.existing_key_expiry_time
}

resource "vault_kv_secret_v2" "s3_credentials" {
  for_each = var.users

  mount = var.vault_mount
  name  = "${local.vault_path_prefix}/${each.key}"

  data_json = jsonencode({
    access_key_id     = powerscale_s3_key.user_key[each.key].access_id
    secret_access_key = powerscale_s3_key.user_key[each.key].secret_key
    username          = each.key
    zone              = var.zone
  })
}
