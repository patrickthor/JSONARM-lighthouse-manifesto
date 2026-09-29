# Native Terraform example

This root module creates one Azure Lighthouse definition and one assignment in the dummy customer subscription. Replace every example UUID before use.

```shell
terraform init -backend=false
terraform plan
```

The executing identity needs permission to create and remove Lighthouse registration resources at the subscription scope. Do not deploy the module's `arm_template_json` output while Terraform manages the same delegation.
