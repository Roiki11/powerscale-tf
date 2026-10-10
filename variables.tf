variable "powerscale_endpoint" {
  description = "PowerScale cluster endpoint."
  type        = string
}

variable "powerscale_username" {
  description = "PowerScale API username."
  type        = string
}

variable "powerscale_password" {
  description = "PowerScale API password."
  type        = string
  sensitive   = true
}

variable "vault_address" {
  description = "Vault server address."
  type        = string
}

variable "zone" {
  description = "Existing PowerScale access zone."
  type        = string
}

variable "users" {
  description = "S3 users and their buckets, keyed by username."
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
}

variable "user_passwords" {
  description = "Optional local PowerScale passwords keyed by username."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "vault_mount" {
  description = "Name of the existing Vault KV v2 secrets-engine mount."
  type        = string
}

variable "vault_path_prefix" {
  description = "Vault path prefix under the KV v2 mount."
  type        = string
  default     = "powerscale/s3"
}
