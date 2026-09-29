# ==============================================================================
# Committed governance record for exactly one customer subscription/state.
#
# Provider authentication, the shared managing tenant ID, and artifact version
# are runtime values. All UUIDs below are dummy values.
# ==============================================================================

customer_subscription_id = "11111111-1111-1111-1111-111111111111"

delegation = {
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
