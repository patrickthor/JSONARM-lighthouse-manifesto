# ARM artifact publication example

This is a data-driven consumer root. Its committed [`terraform.tfvars`](terraform.tfvars) is the governance record: customer keys, offer metadata, managing-tenant principal IDs, permanent roles, eligible roles, activation policy, and approvers are reviewed in pull requests.

Runtime and provider values do not live in that record:

- `managing_tenant_id` is shared across customers and comes from `TF_VAR_managing_tenant_id` or protected repository configuration.
- `artifact_version` comes from the release/workflow.
- Artifact storage coordinates come from protected runtime variables.
- Azure authentication uses the normal `ARM_*` environment variables and targets only the artifact-storage subscription.

## Behavior

`module.lighthouse` uses `for_each = var.customers`, so one committed customer entry produces one independent self-contained ARM template. Stable customer keys also define the private Blob paths:

```text
lighthouse-artifacts/<customer-key>/<artifact-version>/lighthouse.json
```

The core module runs with `deployment_mode = "arm"` and `scope = null`; it creates no Lighthouse resources and never authenticates to customer subscriptions. The configured AzureRM provider is used only to look up the existing artifact storage account/container and upload the JSON.

## Local validation

1. Keep the committed governance file unchanged unless reviewing an access-policy change.
2. Copy `runtime.auto.tfvars.example` to `runtime.auto.tfvars` and replace its dummy runtime values.
3. Authenticate to the artifact-storage subscription.
4. Run:

```shell
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform plan
```

The example does not create the storage account or container. They must already exist, be private, and must not be the Terraform-state container.

## Publication and delivery

Apply only in the consuming artifact-publication environment. Deliver each versioned JSON through an approved private channel without generating SAS tokens here. The customer downloads `lighthouse.json`, opens Azure Portal **Deploy a custom template** or **Service providers > Add offer via template**, selects the target subscription, and deploys with an identity that can manage role assignments at that scope.

This minimal root manages one artifact version per customer at one Terraform resource address. Consumers retaining all historical versions must use separate retained resource/state entries or enforce retention, immutability, and blob versioning in the storage platform.

Never deploy a generated artifact when native Terraform already manages the same delegation.
