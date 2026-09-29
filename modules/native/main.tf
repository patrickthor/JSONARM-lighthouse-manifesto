resource "azurerm_lighthouse_definition" "this" {
  lighthouse_definition_id = var.normalized_delegation.definition_uuid
  name                     = var.normalized_delegation.offer_name
  description              = var.normalized_delegation.offer_description
  managing_tenant_id       = var.normalized_delegation.managing_tenant_id
  scope                    = var.scope

  dynamic "authorization" {
    for_each = {
      for authorization in var.normalized_delegation.permanent_authorizations :
      authorization.key => authorization
    }

    content {
      principal_id           = authorization.value.principal_id
      principal_display_name = authorization.value.principal_display_name
      role_definition_id     = authorization.value.role_definition_id
    }
  }

  dynamic "eligible_authorization" {
    for_each = {
      for authorization in var.normalized_delegation.eligible_authorizations :
      authorization.key => authorization
    }

    content {
      principal_id           = eligible_authorization.value.principal_id
      principal_display_name = eligible_authorization.value.principal_display_name
      role_definition_id     = eligible_authorization.value.role_definition_id

      just_in_time_access_policy {
        maximum_activation_duration = eligible_authorization.value.maximum_activation_duration
        multi_factor_auth_provider  = eligible_authorization.value.multi_factor_auth_provider == "Azure" ? "Azure" : null

        dynamic "approver" {
          for_each = eligible_authorization.value.approvers

          content {
            principal_id           = approver.value.principal_id
            principal_display_name = approver.value.principal_display_name
          }
        }
      }
    }
  }
}

resource "azurerm_lighthouse_assignment" "this" {
  name                     = var.normalized_delegation.assignment_uuid
  scope                    = var.scope
  lighthouse_definition_id = azurerm_lighthouse_definition.this.id
}
