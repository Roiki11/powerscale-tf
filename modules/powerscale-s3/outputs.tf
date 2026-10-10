output "users" {
  description = "PowerScale S3 usernames keyed by the input username."
  value       = { for username, user in powerscale_user.s3_user : username => user.name }
}

output "buckets" {
  description = "Created S3 bucket names keyed by username/bucket name."
  value       = { for key, bucket in powerscale_s3_bucket.bucket : key => bucket.name }
}

output "vault_secret_paths" {
  description = "Vault KV v2 secret paths containing the generated S3 credentials."
  value       = { for username, secret in vault_kv_secret_v2.s3_credentials : username => "${secret.mount}/${secret.name}" }
}

output "bucket_access_key_vault_secret_paths" {
  description = "Vault KV v2 paths for credentials generated for each bucket access key."
  value       = { for key, secret in vault_kv_secret_v2.bucket_access_key_credentials : key => "${secret.mount}/${secret.name}" }
}
