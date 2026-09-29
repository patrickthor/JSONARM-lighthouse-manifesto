locals {
  role_definition_ids = {
    Reader                                                 = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
    Contributor                                            = "b24988ac-6180-42a0-ab88-20f7382dd24c"
    "Managed Services Registration Assignment Delete Role" = "91c1777a-f3dc-4fae-b103-61d183457e46"
  }

  # UUIDv5 URL namespace. The names include separate resource suffixes so the
  # definition and assignment UUIDs are stable but cannot collide.
  uuid_namespace = "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
  identity_seed  = "${lower(var.delegation.managing_tenant_id)}|${trimspace(var.delegation.offer_name)}"
  definition_uuid = uuidv5(
    local.uuid_namespace,
    "${local.identity_seed}|definition"
  )
  assignment_uuid = uuidv5(
    local.uuid_namespace,
    "${local.identity_seed}|assignment"
  )

  permanent_authorizations = merge(
    {},
    [
      for principal_key, principal in var.delegation.principals : {
        for role_name in sort(tolist(principal.permanent_roles)) :
        "${principal_key}/${role_name}" => {
          key                    = "${principal_key}/${role_name}"
          principal_key          = principal_key
          principal_id           = lower(principal.principal_id)
          principal_display_name = trimspace(principal.principal_name)
          role_name              = role_name
          role_definition_id     = local.role_definition_ids[role_name]
        }
      }
    ]...
  )

  eligible_authorizations = merge(
    {},
    [
      for principal_key, principal in var.delegation.principals : {
        for role_name, policy in principal.eligible_roles :
        "${principal_key}/${role_name}" => {
          key                    = "${principal_key}/${role_name}"
          principal_key          = principal_key
          principal_id           = lower(principal.principal_id)
          principal_display_name = trimspace(principal.principal_name)
          role_name              = role_name
          role_definition_id     = local.role_definition_ids[role_name]

          maximum_activation_duration = policy.maximum_activation_duration
          require_mfa                 = policy.require_mfa
          multi_factor_auth_provider  = policy.require_mfa ? "Azure" : "None"
          approvers = [
            for encoded_approver in sort([
              for approver in policy.approvers : jsonencode({
                principal_id           = lower(approver.principal_id)
                principal_display_name = trimspace(approver.principal_name)
              })
            ]) : jsondecode(encoded_approver)
          ]
        }
      }
    ]...
  )

  normalized_permanent_authorizations = [
    for authorization_key in sort(keys(local.permanent_authorizations)) :
    local.permanent_authorizations[authorization_key]
  ]

  normalized_eligible_authorizations = [
    for authorization_key in sort(keys(local.eligible_authorizations)) :
    local.eligible_authorizations[authorization_key]
  ]

  normalized_delegation = {
    offer_name         = trimspace(var.delegation.offer_name)
    offer_description  = var.delegation.offer_description
    managing_tenant_id = lower(var.delegation.managing_tenant_id)
    definition_uuid    = local.definition_uuid
    assignment_uuid    = local.assignment_uuid

    permanent_authorizations = local.normalized_permanent_authorizations
    eligible_authorizations  = local.normalized_eligible_authorizations
  }

  arm_authorizations = [
    for authorization in local.normalized_permanent_authorizations : {
      principalId            = authorization.principal_id
      principalIdDisplayName = authorization.principal_display_name
      roleDefinitionId       = authorization.role_definition_id
    }
  ]

  arm_eligible_authorizations = [
    for authorization in local.normalized_eligible_authorizations : {
      principalId            = authorization.principal_id
      principalIdDisplayName = authorization.principal_display_name
      roleDefinitionId       = authorization.role_definition_id
      justInTimeAccessPolicy = merge(
        {
          maximumActivationDuration = authorization.maximum_activation_duration
          multiFactorAuthProvider   = authorization.multi_factor_auth_provider
        },
        {
          for property_name, property_value in {
            managedByTenantApprovers = [
              for approver in authorization.approvers : {
                principalId            = approver.principal_id
                principalIdDisplayName = approver.principal_display_name
              }
            ]
          } : property_name => property_value if length(authorization.approvers) > 0
        }
      )
    }
  ]

  arm_registration_definition_properties = merge(
    {
      registrationDefinitionName = local.normalized_delegation.offer_name
      description                = local.normalized_delegation.offer_description
      managedByTenantId          = local.normalized_delegation.managing_tenant_id
      authorizations             = local.arm_authorizations
    },
    {
      for property_name, property_value in {
        eligibleAuthorizations = local.arm_eligible_authorizations
      } : property_name => property_value if length(local.arm_eligible_authorizations) > 0
    }
  )

  arm_template = {
    "$schema"      = "https://schema.management.azure.com/schemas/2019-08-01/subscriptionDeploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    metadata = {
      description = "Self-contained Azure Lighthouse delegation generated by Terraform."
      generator   = "azure-lighthouse-delegation-module"
    }
    resources = [
      {
        type       = "Microsoft.ManagedServices/registrationDefinitions"
        apiVersion = "2022-10-01"
        name       = local.definition_uuid
        properties = local.arm_registration_definition_properties
      },
      {
        type       = "Microsoft.ManagedServices/registrationAssignments"
        apiVersion = "2022-10-01"
        name       = local.assignment_uuid
        dependsOn = [
          "[resourceId('Microsoft.ManagedServices/registrationDefinitions', '${local.definition_uuid}')]"
        ]
        properties = {
          registrationDefinitionId = "[resourceId('Microsoft.ManagedServices/registrationDefinitions', '${local.definition_uuid}')]"
        }
      }
    ]
  }

  arm_template_json = jsonencode(local.arm_template)

  offer_slug_candidate = trim(
    replace(lower(trimspace(var.delegation.offer_name)), "/[^0-9a-z]+/", "-"),
    "-"
  )
  version_slug_candidate = trim(
    replace(lower(trimspace(var.artifact_version)), "/[^0-9a-z._-]+/", "-"),
    "-."
  )
  offer_slug            = local.offer_slug_candidate != "" ? local.offer_slug_candidate : "lighthouse"
  artifact_version_slug = local.version_slug_candidate != "" ? local.version_slug_candidate : "version"
  suggested_artifact_name = format(
    "%s-%s-lighthouse.json",
    local.offer_slug,
    local.artifact_version_slug
  )
}
