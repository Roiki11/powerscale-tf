output "users" {
  description = "PowerScale S3 usernames keyed by the input username."
  value       = module.powerscale_s3.users
}

output "buckets" {
  description = "Created S3 bucket names keyed by username/bucket name."
  value       = module.powerscale_s3.buckets
}

output "vault_secret_paths" {
  description = "Vault KV v2 secret paths containing the generated S3 credentials."
  value       = module.powerscale_s3.vault_secret_paths
}
