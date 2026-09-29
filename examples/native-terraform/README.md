# Native Terraform example

This consumer root manages exactly one customer subscription and one Azure Lighthouse delegation per state. Its committed [`terraform.tfvars`](terraform.tfvars) is the reviewed governance record containing the customer subscription, offer, principals, roles, JIT settings, and approvers.

Runtime values are separate:

- `managing_tenant_id` comes from `TF_VAR_managing_tenant_id` or protected repository configuration.
- `artifact_version` comes from the release/workflow; the module still exposes ARM JSON for inspection.
- Provider authentication uses the standard `ARM_*` environment variables. `provider_subscription_id` comes from `TF_VAR_provider_subscription_id` or protected repository configuration and is validated to equal the committed `customer_subscription_id`.

For local validation, copy `runtime.auto.tfvars.example` to ignored `runtime.auto.tfvars`, authenticate to the dummy replacement customer subscription, and run:

```shell
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform plan
```

Use one state key or workspace per customer. Do not combine unrelated customer subscriptions in one native state: provider contexts cannot be selected dynamically with `for_each`, and a shared state increases cross-customer blast radius.

The executing identity needs permission to create and remove Lighthouse registration resources at the subscription scope. Do not deploy the module's `arm_template_json` output while Terraform manages the same delegation.
