# Azure Lighthouse delegation module

This repository provides one strongly typed Azure Lighthouse delegation model with two mutually exclusive delivery paths:

| Mode | Behavior |
| --- | --- |
| `terraform` | Creates one `azurerm_lighthouse_definition` and one `azurerm_lighthouse_assignment` in the customer subscription. |
| `arm` | Creates no Lighthouse resources and returns one self-contained subscription-scope ARM template JSON string. |

Both paths consume the same canonical authorization model, role IDs, deterministic resource names, and JIT policy settings. The ARM JSON is also available in `terraform` mode for inspection, but **must not be deployed when Terraform manages the same delegation**.

The previous static multi-subscription manifest has been superseded. Instantiate this module once per customer subscription so each delegation has one owner and lifecycle.

## Architecture and trust boundary

The managing service-provider Microsoft Entra tenant owns:

- Consultant identities and security groups.
- Access packages and access reviews.
- Approver identities.
- Conditional Access policies.
- PIM licensing used by eligible Lighthouse authorizations.

The customer tenant owns the subscription and approves or deploys the delegation. This module only manages or renders Azure Lighthouse registration resources. It does not:

- Create Entra users, groups, access packages, access reviews, or Conditional Access policies.
- Require the `azuread` provider.
- Create direct customer RBAC assignments outside Azure Lighthouse.
- Configure PIM for Groups.
- Publish artifacts or create storage resources.
- Generate credentials, storage keys, or SAS tokens.

Customer-tenant Conditional Access does not govern consultants using Azure Lighthouse. Conditional Access in the managing tenant must protect those identities.

## Requirements

- Terraform `>= 1.9, < 2.0`.
- AzureRM provider `~> 5.4.0`.
- Microsoft Entra ID Governance licensing that supports PIM in the managing tenant when eligible authorizations are used.
- For native deployment, an identity authorized to create and remove Lighthouse registration resources at the customer subscription scope.
- For portal deployment, the customer normally uses an `Owner` identity, or another identity that can read, write, and delete role assignments at the target scope.

The module initially supports subscription scope only.

Because Terraform discovers provider dependencies statically, a normal plan of this dual-mode module still needs an explicit AzureRM provider configuration in `arm` mode. It can use the artifact-storage provider, as the ARM example does. ARM rendering never reads the customer subscription, does not embed its ID, and requires no customer-subscription credentials.

## Public interface

```hcl
module "lighthouse" {
  source = "path/to/this/module"

  deployment_mode = "terraform" # terraform | arm
  scope            = "/subscriptions/11111111-1111-1111-1111-111111111111"
  artifact_version = "2026.01.0"

  delegation = {
    offer_name         = "Example Customer Managed Services"
    offer_description  = "Delegated subscription management."
    managing_tenant_id = "22222222-2222-2222-2222-222222222222"

    principals = {
      platform_operators = {
        principal_id    = "33333333-3333-3333-3333-333333333333"
        principal_name  = "Example Platform Operators"
        permanent_roles = ["Reader"]

        eligible_roles = {
          Contributor = {
            maximum_activation_duration = "PT2H"
            require_mfa                  = true
            approvers = [{
              principal_id   = "44444444-4444-4444-4444-444444444444"
              principal_name = "Example Lighthouse Approvers"
            }]
          }
        }
      }
    }
  }
}
```

The keys under `principals` are stable Terraform identity keys. Keep them static and do not derive them from resource attributes that are unknown during planning. Azure object UUIDs remain values.

## Consumer governance pattern

The core module intentionally accepts one customer delegation. The reference consumers move customer-specific policy out of `main.tf` and into narrowly unignored, committed `terraform.tfvars` files so access changes arrive as reviewed pull requests:

- [`examples/arm-artifact/terraform.tfvars`](examples/arm-artifact/terraform.tfvars) is a map of customers. The generic root uses `for_each` to render and publish one ARM artifact per stable customer key.
- [`examples/native-terraform/terraform.tfvars`](examples/native-terraform/terraform.tfvars) contains exactly one customer subscription and delegation. Native deployments should use one state/provider execution per customer.

The governance files contain no credentials. They hold subscription IDs, group and approver object IDs, offer metadata, role choices, and JIT policy. Shared/runtime values are intentionally separate:

| Value | Recommended source |
| --- | --- |
| Managing tenant ID | `TF_VAR_managing_tenant_id` or protected repository variable |
| Artifact version | Release tag or manually approved workflow input |
| Azure authentication | OIDC and standard `ARM_*` environment variables |
| Native provider subscription | `TF_VAR_provider_subscription_id`; validated against committed customer scope |
| Artifact storage coordinates | Protected runtime variables |
| Delegation policy | Committed governance tfvars |

The consumer roots declare the nested governance variables as `any` to avoid copying this module's typed schema and validations. The module remains the authoritative contract. Stable customer and principal map keys are configuration-derived so `for_each` identities are known during planning.

Do not expose `deployment_mode` as a casual workflow toggle. The ARM and native reference roots fix their mode in code because changing ownership mode can destroy or conflict with an existing delegation.

### Committed tfvars allowlist

The repository ignores tfvars by default and unignores only the two known, non-secret governance files. Runtime copies such as `runtime.auto.tfvars` remain ignored. Apply the same narrow allowlist in a consuming repository rather than globally committing every tfvars file.

### Inputs

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `artifact_version` | `string` | Yes | Immutable consumer-defined version used in the suggested artifact filename. |
| `delegation` | `object` | Yes | Offer metadata, managing tenant, principals, permanent roles, and eligible policies. |
| `deployment_mode` | `string` | Yes | Exactly `terraform` or `arm`. |
| `scope` | `string` or `null` | Mode-dependent | Subscription ID in `/subscriptions/<uuid>` form for Terraform; must be `null` for ARM. |

### Role allowlist

The role-name-to-ID mapping exists once in `locals.tf` and drives both renderers:

| Module role name | Built-in role ID |
| --- | --- |
| `Reader` | `acdd72a7-3385-48ef-bd42-f606fba81ae7` |
| `Contributor` | `b24988ac-6180-42a0-ab88-20f7382dd24c` |
| `Managed Services Registration Assignment Delete Role` | `91c1777a-f3dc-4fae-b103-61d183457e46` |

Arbitrary UUIDs and custom roles are intentionally rejected. Expanding the allowlist requires an explicit module change backed by a current Lighthouse role-support review.

## Canonical model and deterministic identity

`locals.tf` expands the input once into deterministic permanent and eligible authorization collections. It normalizes role UUIDs, MFA provider values, approvers, ordering, and stable `<principal-key>/<role-name>` keys. Both the ARM renderer and the conditional native submodule consume this normalized model.

Definition and assignment UUIDs use UUIDv5 over the lowercased managing tenant ID, the trimmed **case-sensitive** offer name, and separate resource suffixes. Offer-name case changes therefore create different resource identities rather than attempting a same-ID ForceNew replacement. Treat `offer_name` as immutable unless following the rename procedure below.

## Native Terraform deployment

See [`examples/native-terraform`](examples/native-terraform).

In `terraform` mode the module:

1. Requires a customer subscription scope.
2. Enables the internal `modules/native` implementation.
3. Creates one `azurerm_lighthouse_definition` from the canonical permanent and eligible authorizations.
4. Creates one `azurerm_lighthouse_assignment` at the same scope.
5. Returns both native resource IDs.

Review the plan before applying. The caller supplies the default AzureRM provider configured for the customer subscription.

## Self-contained ARM artifact

See [`examples/arm-artifact`](examples/arm-artifact).

In `arm` mode:

- The internal native module has `count = 0`, so no Lighthouse definition or assignment is planned.
- `scope` must be `null`; the customer selects the subscription in Azure Portal.
- `arm_template_json` contains a complete parameter-free subscription deployment template.
- The template contains `Microsoft.ManagedServices/registrationDefinitions` and `Microsoft.ManagedServices/registrationAssignments` at API version `2022-10-01`.
- The assignment depends on and references the definition in the same template.
- Empty approver collections are omitted rather than emitted as `null`.
- Every value is derived from inputs and locals, never from a created Azure resource.

Write the exact output to a file when needed:

```shell
terraform output -raw arm_template_json > lighthouse.json
```

The customer deploys it through **Azure Portal > Deploy a custom template > Build your own template in the editor > Load file**, or **Service providers > Add offer via template**. Each customer subscription requires its own deployment.

Authorization changes in the manual path require regeneration, customer review, and customer redeployment.

## Artifact publication boundary

The core module never creates or selects remote storage. The consuming repository or pipeline owns artifact publication, access grants, retention, blob versioning, immutability, and customer delivery.

The ARM example uses an aliased AzureRM provider to upload `source_content` to an existing private container with content type `application/json`:

```text
lighthouse-artifacts/<customer-key>/<artifact-version>/lighthouse.json
```

Use a dedicated artifact container, never the Terraform-state container. Use path-safe immutable version identifiers and do not generate SAS tokens in this module. Artifact storage can be in a separate subscription from native customer deployment.

The minimal example manages one artifact version at one resource address. A production publisher that retains every version should model versions as separate retained resource/state entries or enforce retention and immutability in the storage platform.

## Validation and guardrails

Planning fails with a targeted message when:

- The mode is not exactly `terraform` or `arm`.
- Terraform mode lacks a valid subscription scope, or ARM mode receives a non-null scope.
- No authorization exists, or a principal has no roles.
- Managing tenant, principal, or approver IDs are not UUID-shaped.
- Offer, principal, or approver names are empty.
- A role is outside the allowlist.
- A principal with an eligible role lacks an explicit permanent `Reader` authorization.
- Activation duration is not a half-hour increment from `PT30M` through `PT8H`.
- An eligible authorization has more than 10 approvers.
- An eligible principal is also an approver for its own activation.
- Two instances of the same eligible role have different duration, MFA, or approver policies.
- Duplicate permanent or eligible principal/role pairs exist under different map keys.
- A principal/role pair is both permanent and eligible.

## Lighthouse constraints

- Eligible authorizations support MFA, activation duration, and optional managing-tenant approvers.
- Activation duration is between 30 minutes and 8 hours.
- AzureRM represents `require_mfa = false` by omitting its MFA field; the provider sends `None`. The ARM renderer emits `None` explicitly. Both are semantically identical.
- Eligible service principals are unsupported. The module accepts object IDs but cannot determine principal type without the `azuread` provider, so consumers must use users or groups for eligible entries.
- Every eligible principal needs a separate permanent `Reader` authorization to elevate through Azure Portal. This module requires `Reader` exactly.
- Justification, ticket information, and Conditional Access authentication context are not part of the Lighthouse eligible-authorization schema and are not configurable here.
- Azure Lighthouse does not support `Owner`, custom roles, roles with `DataActions`, or broad `User Access Administrator` use. The module allowlist avoids these cases.
- Removing a consultant from the managing-tenant security group removes effective permanent Reader and eligible Contributor access without customer redeployment. Propagation might not be immediate.
- Customer Azure Activity Log records identify the individual consultant performing actions.
- Native Terraform and manual ARM must never manage the same delegation concurrently.

## Updates, renames, migration, and removal

### Normal updates

- **Native:** change consumer input, review the Terraform plan, and apply. Terraform owns both registration resources.
- **ARM:** regenerate and publish a new immutable artifact version; the customer reviews and redeploys it.
- **Group membership:** change membership in the managing tenant. No customer redeployment is needed.

### Renaming an offer or changing managing tenant

An ARM deployment with a new deterministic name does not remove the old offer. For a renamed offer that reuses principals, the customer must remove the old delegation **before** deploying the renamed artifact; otherwise conflicting assignments can interrupt or obscure access. Use a maintenance window and a rollback artifact. Treat a managing-tenant change as removal and fresh onboarding.

Native Terraform also replaces resources when identity inputs change. Review destroy/create ordering and schedule a maintenance window rather than assuming uninterrupted access.

### Switching from Terraform to ARM

1. While still in Terraform mode, export and approve the already-available ARM JSON.
2. Schedule a maintenance window and rollback plan.
3. Change to ARM mode and apply so Terraform removes its assignment and definition.
4. Confirm removal, then have the customer deploy the approved artifact.

There is an expected access gap between steps 3 and 4. Never deploy the ARM artifact before Terraform relinquishes ownership.

### Switching from ARM to Terraform

Do not apply Terraform directly over an existing manual delegation. Either:

- Set Terraform mode and import the existing deterministic definition and assignment into `module.<name>.module.native[0].azurerm_lighthouse_definition.this` and `.azurerm_lighthouse_assignment.this` before planning; or
- Have the customer remove the manual delegation, confirm removal, and then apply Terraform during a maintenance window.

The second option creates an access gap. Verify import addresses against the consuming module path and back up state before migration.

### Removal

In native mode, remove the module or destroy its resources through Terraform. In ARM mode, the customer removes the service-provider offer, or an authorized managing-tenant principal uses `Managed Services Registration Assignment Delete Role` when included.

## Outputs

| Name | Description |
| --- | --- |
| `arm_template_json` | Exact self-contained ARM JSON, available in both modes. |
| `arm_template_sha256` | SHA-256 of exactly `arm_template_json`. |
| `lighthouse_assignment_id` | Native assignment ID in Terraform mode; otherwise `null`. |
| `lighthouse_definition_id` | Native definition ID in Terraform mode; otherwise `null`. |
| `normalized_delegation` | Non-sensitive canonical representation used by both paths. |
| `suggested_artifact_name` | Sanitized offer/version-based JSON filename. |

Tenant IDs, object IDs, role IDs, and generated template JSON are identifiers, not credentials, so outputs are not marked sensitive.

## Local validation

Run for the module and each example:

```shell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

No command in this repository applies or destroys real infrastructure.

## References

- [Onboard a customer to Azure Lighthouse](https://learn.microsoft.com/azure/lighthouse/how-to/onboard-customer)
- [Create eligible authorizations](https://learn.microsoft.com/azure/lighthouse/how-to/create-eligible-authorizations)
- [Microsoft.ManagedServices registrationDefinitions 2022-10-01](https://learn.microsoft.com/azure/templates/microsoft.managedservices/2022-10-01/registrationdefinitions)
- [Azure Lighthouse role support](https://learn.microsoft.com/azure/lighthouse/concepts/tenants-users-roles#role-support-for-azure-lighthouse)
- [Terraform `jsonencode`](https://developer.hashicorp.com/terraform/language/functions/jsonencode)

Microsoft documentation is summarized and rephrased here.
