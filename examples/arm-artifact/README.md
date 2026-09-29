# ARM artifact publication example

This root module sets `deployment_mode = "arm"`, so the core module creates no Lighthouse definition or assignment. It uploads the generated JSON to an existing private Blob container through an aliased AzureRM provider. The storage account and container are not created here and must not be the Terraform-state container.

1. Copy `terraform.tfvars.example` to a non-committed `terraform.tfvars` and replace all dummy storage values.
2. Authenticate the aliased provider to the artifact-storage subscription; no customer-subscription authentication is used for ARM generation.
3. Run `terraform init -backend=false` and review `terraform plan`.
4. Apply only in the consuming artifact-publication environment.
5. Deliver the versioned JSON to the customer through an approved private channel; do not issue SAS tokens from this example.
6. The customer downloads `lighthouse.json`, opens Azure Portal **Deploy a custom template** (or **Service providers > Add offer via template**), selects the target subscription, uploads the file, and deploys it with an identity that can manage role assignments at that scope.

The immutable blob path is:

```text
lighthouse-artifacts/<customer-key>/<artifact-version>/lighthouse.json
```

This minimal example manages one artifact version at one Terraform resource address. Changing `artifact_version` creates a new versioned path and removes the prior blob from this example's state. Consumers that retain every version must model each version as a distinct resource/state entry or enforce retention, immutability, and blob versioning in the storage platform. Those controls intentionally remain outside the core module.

To save the module output locally instead of publishing it:

```shell
terraform output -raw arm_template_json > lighthouse.json
```

Never deploy this manual artifact when native Terraform already manages the same delegation.
