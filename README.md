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

Copy [`terraform.tfvars.example`](./terraform.tfvars.example) to
`terraform.tfvars` and replace the placeholder values with your environment's
settings. The root `.gitignore` excludes `*.tfvars` files to help prevent
credentials from being committed. Do not put real passwords in the example
file; provide them through a secret manager or another protected source.

Set Vault authentication through the standard Vault environment or agent
configuration, for example `VAULT_TOKEN` where appropriate.

## Module inputs

The reusable child module is `modules/powerscale-s3`. Provider configuration is
supplied by the calling root module; the Dell PowerScale and HashiCorp Vault
providers are required.

| Variable | Type | Required/default | Description and accepted values |
|---|---|---|---|
| `zone` | `string` | Required | Existing PowerScale access zone. Must not be empty; use the exact name configured on the cluster. |
| `users` | `map(object)` | Required | Map keyed by non-empty PowerScale username. Each value configures the user, optional buckets, and optional key-rotation grace period; see the nested fields below. |
| `user_passwords` | `map(string)` | Optional; `{}` | Optional local-user passwords keyed by username. Sensitive. Keep secrets out of source control. |
| `vault_mount` | `string` | Required | Name of the existing Vault KV v2 secrets-engine mount, without a path suffix. Must not be empty. |
| `vault_path_prefix` | `string` | Optional; `"powerscale/s3"` | Path prefix under the mount. Must contain a non-slash character; leading and trailing `/` are trimmed. One secret is written per username. |

### `users` fields

| Field | Type | Required/default | Description and accepted values |
|---|---|---|---|
| `email` | `string` | Optional | Email address stored on the local PowerScale user. |
| `buckets` | `map(object)` | Optional; `{}` | Buckets keyed by bucket name. Each bucket is owned by its associated user and created in the configured zone. |
| `existing_key_expiry_time` | `number` | Optional | Number of minutes the previous secret key remains valid after a key update. Must be zero or greater. This is not an expiration for the new key. |

### `users[*].buckets[*]` fields

| Field | Type | Required/default | Description and accepted values |
|---|---|---|---|
| `path` | `string` | Required | PowerScale filesystem path for the bucket, for example `/ifs/s3/analytics/reports`. |
| `create_path` | `bool` | Default: `true` | `true` or `false`; whether PowerScale should create the filesystem path if it does not exist. |
| `description` | `string` | Required | Bucket description. Use `""` when no description is needed. |
| `acl` | `list(object)` | Optional | S3 access-control entries. If omitted, provider default ACL behavior applies. |
| `access_keys` | `map(object)` | Optional; `{}` | Named credentials for this bucket. Each entry creates a dedicated PowerScale user and S3 key, grants that user the configured bucket ACL permission, and stores the credentials in Vault. |

Each `acl` entry has these fields:

| Field | Type | Required | Accepted values |
|---|---|---|---|
| `grantee.name` | `string` | Yes | Name of the PowerScale user, group, or well-known persona to grant access to. |
| `grantee.type` | `string` | Yes | `user`, `group`, or `wellknown`. |
| `permission` | `string` | Yes | `READ`, `WRITE`, `READ_ACP`, `WRITE_ACP`, or `FULL_CONTROL`. |

Each `access_keys` entry is keyed by a credential label (a non-empty path
segment without `/`) and has these fields:

| Field | Type | Required/default | Description and accepted values |
|---|---|---|---|
| `username` | `string` | Required | Dedicated local PowerScale username for this credential. Must be non-empty, unique across the module, and different from the bucket owner username. |
| `permission` | `string` | Required | Automatically grants this user access to the bucket. Accepted values are `READ`, `WRITE`, `READ_ACP`, `WRITE_ACP`, and `FULL_CONTROL`. |
| `email` | `string` | Optional | Email address stored on the dedicated PowerScale user. |
| `existing_key_expiry_time` | `number` | Optional | Grace period for the previous key after rotation, in minutes. Must be zero or greater; does not expire the newly generated key. |

## Module behavior

The module creates local PowerScale users in the specified zone, assigns
configured buckets to their users, generates one S3 key per user, and writes
each credential to `<vault_mount>/<vault_path_prefix>/<username>` in Vault KV
v2. Bucket access key credentials are written beneath
`<vault_mount>/<vault_path_prefix>/<owner>/<bucket>/<key-label>`. Each secret
contains `access_key_id`, `secret_access_key`, `username`, and `zone`; bucket
key secrets also include `bucket`.

PowerScale S3 keys are user-scoped, not bucket-scoped. To provide multiple
independent credentials per bucket, each `access_keys` entry creates a dedicated
local user and key, then adds that user to the bucket ACL with the requested
permission.

Credential material is not exposed as a Terraform output, but it is present in
Terraform state while managed. Use an encrypted, access-controlled backend and
protect state backups and plans. Vault credentials must be able to write to the
selected KV v2 mount.
