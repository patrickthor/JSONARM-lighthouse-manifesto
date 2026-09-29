# ==============================================================================
# Committed governance record
#
# This file intentionally belongs in git. It describes which customer offers,
# managing-tenant groups, permanent roles, eligible roles, and approvers exist.
# Provider authentication, the shared managing tenant ID, storage coordinates,
# and artifact version are supplied separately at runtime.
#
# All UUIDs below are dummy values.
# ==============================================================================

customers = {
  "example-customer" = {
    offer_name        = "Example Customer Managed Services"
    offer_description = "Delegated subscription management through Azure Lighthouse."

    principals = {
      platform_operators = {
        principal_id    = "33333333-3333-3333-3333-333333333333"
        principal_name  = "Example Platform Operators"
        permanent_roles = ["Reader"]

        eligible_roles = {
          Contributor = {
            maximum_activation_duration = "PT2H"
            require_mfa                 = true
            approvers = [
              {
                principal_id   = "44444444-4444-4444-4444-444444444444"
                principal_name = "Example Lighthouse Approvers"
              }
            ]
          }
        }
      }
    }
  }
}
