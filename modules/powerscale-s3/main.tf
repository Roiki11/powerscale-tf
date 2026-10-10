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
          access_keys = definition.access_keys
        }
      ]
    ]) : bucket.key => bucket
  }

  bucket_access_keys = {
    for access_key in flatten([
      for username, user in var.users : flatten([
        for bucket_name, bucket in user.buckets : [
          for access_key_name, access_key in bucket.access_keys : {
            key                      = "${username}/${bucket_name}/${access_key_name}"
            owner_username           = username
            bucket_name              = bucket_name
            access_key_name          = access_key_name
            username                 = access_key.username
            email                    = access_key.email
            permission               = access_key.permission
            existing_key_expiry_time = access_key.existing_key_expiry_time
          }
        ]
      ])
    ]) : access_key.key => access_key
  }

  vault_path_prefix = trim(trimspace(var.vault_path_prefix), "/")
}

resource "powerscale_user" "s3_user" {
  for_each = var.users

  name           = each.key
  query_zone     = var.zone
  email          = each.value.email
  password       = lookup(var.user_passwords, each.key, null)
  home_directory = "/ifs/data/${each.key}"
  shell          = "/bin/nologin"
}

resource "powerscale_user" "bucket_access_key_user" {
  for_each = local.bucket_access_keys

  name           = each.value.username
  query_zone     = var.zone
  email          = each.value.email
  home_directory = "/ifs/data/${each.value.username}"
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
  acl = concat(
    coalesce(each.value.acl, []),
    [
      for access_key_name, access_key in each.value.access_keys : {
        grantee = {
          name = powerscale_user.bucket_access_key_user["${each.value.username}/${each.value.name}/${access_key_name}"].name
          type = "user"
        }
        permission = access_key.permission
      }
    ]
  )
}

resource "powerscale_s3_key" "user_key" {
  for_each = var.users

  user                     = powerscale_user.s3_user[each.key].name
  zone                     = var.zone
  existing_key_expiry_time = each.value.existing_key_expiry_time
}

resource "powerscale_s3_key" "bucket_access_key" {
  for_each = local.bucket_access_keys

  user                     = powerscale_user.bucket_access_key_user[each.key].name
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

resource "vault_kv_secret_v2" "bucket_access_key_credentials" {
  for_each = local.bucket_access_keys

  mount = var.vault_mount
  name  = "${local.vault_path_prefix}/${each.value.owner_username}/${each.value.bucket_name}/${each.value.access_key_name}"

  data_json = jsonencode({
    access_key_id     = powerscale_s3_key.bucket_access_key[each.key].access_id
    secret_access_key = powerscale_s3_key.bucket_access_key[each.key].secret_key
    username          = each.value.username
    zone              = var.zone
    bucket            = each.value.bucket_name
  })
}
