# ARM artifact publication example

This is a data-driven consumer root. Its committed [`terraform.tfvars`](terraform.tfvars) is the governance record: customer keys, offer metadata, managing-tenant principal IDs, permanent roles, eligible roles, activation policy, and approvers are reviewed in pull requests.

Runtime and provider values do not live in that record:

- `managing_tenant_id` is shared across customers and comes from `TF_VAR_managing_tenant_id` or protected repository configuration.
- `artifact_version` comes from the release/workflow.
- Artifact storage coordinates come from protected runtime variables.
- Azure authentication uses the normal `ARM_*` environment variables and targets only the artifact-storage subscription.

This example expects an environment-specific storage account dedicated to artifacts and an existing private container. It must never use the Terraform backend/state storage account or its containers. Use separate publication destinations for environments such as dev, test, and prod. Azure Blob Storage is only the reference implementation; a consuming repository may publish the returned content to an equivalent private artifact repository instead.

The Blob reference uses these runtime inputs consistently:

- `artifact_storage_subscription_id`
- `artifact_storage_resource_group_name`
- `artifact_storage_account_name`
- `artifact_storage_container_name`

## Behavior

`module.lighthouse` uses `for_each = var.customers`, so one committed customer entry produces one independent self-contained ARM template. Stable customer keys also define the immutable, versioned private Blob paths:

```text
lighthouse-artifacts/<customer-key>/<artifact-version>/lighthouse.json
```

The core module runs with `deployment_mode = "arm"` and `scope = null`; it creates no Lighthouse or storage resources and never authenticates to customer subscriptions. It remains storage-independent and only returns `arm_template_json`, `arm_template_sha256`, and `suggested_artifact_name` as its artifact outputs, alongside its existing native and diagnostic outputs. Those values derive from module inputs and locals, not from remote storage.

The consuming example root uses the aliased AzureRM provider to resolve the existing storage account and private container and publishes `arm_template_json` as `application/json`. Storage lookups and Blob publication are not core-module responsibilities.

## Local validation

1. Keep the committed governance file unchanged unless reviewing an access-policy change.
2. Copy `runtime.auto.tfvars.example` to `runtime.auto.tfvars` and replace its dummy runtime values with the dedicated artifact destination for the current environment.
3. Authenticate to the artifact-storage subscription.
4. Run:

```shell
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform plan
```

The example only resolves and publishes to the configured storage account and container. Both must already exist, the container must be private, and neither may be Terraform backend/state storage.

## Publication and delivery responsibilities

Apply only in the consuming artifact-publication environment. The consuming repository or platform is responsible for:

- Provisioning the dedicated artifact storage account and private container, or equivalent private artifact repository.
- Azure RBAC and data-plane access for the publisher and approved consumers.
- Network restrictions, including private endpoints and firewall policy where required.
- Retention, immutability, and versioning controls.
- Secure delivery of approved artifacts to customers.

Do not add those concerns to the core Lighthouse module. This example does not generate SAS tokens, credentials, or storage keys. Deliver each versioned JSON through an approved private channel. The customer downloads `lighthouse.json`, opens Azure Portal **Deploy a custom template** or **Service providers > Add offer via template**, selects the target subscription, and deploys with an identity that can manage role assignments at that scope.

This minimal root manages one artifact version per customer at one Terraform resource address. Consumers retaining all historical versions must use separate retained resource/state entries or enforce retention, immutability, and blob versioning in the storage platform.

Never deploy a generated artifact when native Terraform already manages the same delegation.
