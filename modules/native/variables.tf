variable "normalized_delegation" {
  type = object({
    offer_name         = string
    offer_description  = string
    managing_tenant_id = string
    definition_uuid    = string
    assignment_uuid    = string

    permanent_authorizations = list(object({
      key                    = string
      principal_key          = string
      principal_id           = string
      principal_display_name = string
      role_name              = string
      role_definition_id     = string
    }))

    eligible_authorizations = list(object({
      key                         = string
      principal_key               = string
      principal_id                = string
      principal_display_name      = string
      role_name                   = string
      role_definition_id          = string
      maximum_activation_duration = string
      require_mfa                 = bool
      multi_factor_auth_provider  = string
      approvers = list(object({
        principal_id           = string
        principal_display_name = string
      }))
    }))
  })
  description = "Canonical validated delegation model produced by the parent module."
}

variable "scope" {
  type        = string
  description = "Customer subscription resource ID for the native Lighthouse resources."
}
