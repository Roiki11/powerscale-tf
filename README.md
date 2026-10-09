# PowerScale S3 module

The reusable child module is in [`modules/powerscale-s3`](./modules/powerscale-s3).
The Terraform files at the repository root form a runnable example root module
that configures the providers and calls the child module.

## Requirements

- Terraform 1.3 or later
- Dell `powerscale` provider 1.8.3 or later (before 2.0)
- HashiCorp `vault` provider 5.12.0 or later (before 6.0)
- An existing PowerScale access zone and Vault KV v2 secrets engine

## Configure and apply the example

Configure the required root-module variables using a protected `.tfvars` file,
environment variables, or your automation platform. The root `.gitignore`
excludes `*.tfvars` files.

Example `terraform.tfvars`:

```terraform
powerscale_endpoint = "https://powerscale.example.com"
powerscale_username = "terraform"
powerscale_password = "use-a-secret-manager"
vault_address       = "https://vault.example.com"
zone                = "s3-zone"
vault_mount         = "secret"
vault_path_prefix   = "powerscale/s3"

users = {
  analytics = {
    uid = 12001
    buckets = {
      reports = {
        path        = "/ifs/s3/analytics/reports"
        create_path = true
        description = "Analytics reports"
        acl = [
          {
            grantee = {
              name = "analytics"
              type = "user"
            }
            permission = "FULL_CONTROL"
          }
        ]
      }
    }
  }

  backup = {
    buckets = {
      archive = {
        path = "/ifs/s3/backup/archive"
      }
    }
    # Grace period for the old key after rotation, in minutes.
    existing_key_expiry_time = 60
  }
}
```

Set Vault authentication through the standard Vault environment or agent
configuration, for example `VAULT_TOKEN` where appropriate. Then run:

```shell
terraform init
terraform plan
terraform apply
```

## Module behavior

The child module creates local PowerScale users in the specified zone, assigns
configured buckets to their users, generates one S3 key per user, and writes
each credential to `<vault_mount>/<vault_path_prefix>/<username>` in Vault KV
v2. Secret data contains `access_key_id`, `secret_access_key`, `username`, and
`zone`.

Each bucket can optionally specify an `acl` list. Each entry requires a
`grantee` with `name` and `type`, and a `permission` of `READ`, `WRITE`,
`READ_ACP`, `WRITE_ACP`, or `FULL_CONTROL`. If `acl` is omitted, the provider's
default ACL behavior is used.

`existing_key_expiry_time` is PowerScale's old-key grace period after a key
update. It does not set an expiration for a newly generated key; the provider
does not expose a lifetime for new keys.

Credential material is not exposed as a Terraform output, but it is present in
Terraform state while managed. Use an encrypted, access-controlled backend and
protect state backups and plans. Vault credentials must be able to write to the
selected KV v2 mount.
