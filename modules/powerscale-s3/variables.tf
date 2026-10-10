variable "zone" {
  description = "Existing PowerScale access zone in which to create the S3 users and buckets."
  type        = string

  validation {
    condition     = length(trimspace(var.zone)) > 0
    error_message = "zone must not be empty."
  }
}

variable "users" {
  description = <<-EOT
    S3 users keyed by username. Each user's optional buckets are keyed by bucket
    name, with a PowerScale filesystem path supplied for each bucket.
    existing_key_expiry_time, when set, is the number of minutes an existing
    secret key remains valid after a key update; it does not expire the new key.
  EOT
  type = map(object({
    email = optional(string)
    buckets = optional(map(object({
      path        = string
      create_path = optional(bool, true)
      description = string
      access_keys = optional(map(object({
        username                 = string
        permission               = string
        email                    = optional(string)
        existing_key_expiry_time = optional(number)
      })), {})
      acl = optional(list(object({
        grantee = object({
          name = string
          type = string
        })
        permission = string
      })))
    })), {})
    existing_key_expiry_time = optional(number)
  }))

  validation {
    condition = (
      alltrue([
        for username, user in var.users :
        length(trimspace(username)) > 0 &&
        (user.existing_key_expiry_time == null || user.existing_key_expiry_time >= 0) &&
        alltrue(flatten([
          for bucket in values(user.buckets) : [
            for acl_entry in coalesce(bucket.acl, []) :
            contains(["READ", "WRITE", "READ_ACP", "WRITE_ACP", "FULL_CONTROL"], acl_entry.permission)
          ]
        ])) &&
        alltrue(flatten([
          for bucket in values(user.buckets) : [
            for access_key_name, access_key in bucket.access_keys :
            length(trimspace(access_key_name)) > 0 &&
            length(split("/", access_key_name)) == 1 &&
            length(trimspace(access_key.username)) > 0 &&
            !contains(keys(var.users), access_key.username) &&
            contains(["READ", "WRITE", "READ_ACP", "WRITE_ACP", "FULL_CONTROL"], access_key.permission) &&
            (access_key.existing_key_expiry_time == null || access_key.existing_key_expiry_time >= 0)
          ]
        ]))
      ]) &&
      length(flatten([
        for user in values(var.users) : flatten([
          for bucket in values(user.buckets) : [
            for access_key in values(bucket.access_keys) : access_key.username
          ]
        ])
        ])) == length(toset(flatten([
          for user in values(var.users) : flatten([
            for bucket in values(user.buckets) : [
              for access_key in values(bucket.access_keys) : access_key.username
            ]
          ])
      ])))
    )
    error_message = "Usernames must be non-empty and unique; access key names must be non-empty path segments; key expiry must be zero or greater; and ACL permissions must be READ, WRITE, READ_ACP, WRITE_ACP, or FULL_CONTROL."
  }
}

variable "user_passwords" {
  description = "Optional local PowerScale passwords keyed by username. Keep sensitive values out of source control."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "vault_mount" {
  description = "Name of the existing Vault KV v2 secrets engine mount."
  type        = string

  validation {
    condition     = length(trimspace(var.vault_mount)) > 0
    error_message = "vault_mount must not be empty."
  }
}

variable "vault_path_prefix" {
  description = "Path prefix under the KV v2 mount; one secret named for each user is written beneath it."
  type        = string
  default     = "powerscale/s3"

  validation {
    condition     = length(trim(trimspace(var.vault_path_prefix), "/")) > 0
    error_message = "vault_path_prefix must contain at least one non-slash character."
  }
}
