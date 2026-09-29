terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "11111111-1111-1111-1111-111111111111"
}

module "lighthouse" {
  source = "../.."

  artifact_version = "2026.01.0"
  deployment_mode  = "terraform"
  scope            = "/subscriptions/11111111-1111-1111-1111-111111111111"

  delegation = {
    offer_name         = "Example Customer Managed Services"
    offer_description  = "Delegated subscription management through Azure Lighthouse."
    managing_tenant_id = "22222222-2222-2222-2222-222222222222"

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

output "lighthouse_assignment_id" {
  value = module.lighthouse.lighthouse_assignment_id
}

output "lighthouse_definition_id" {
  value = module.lighthouse.lighthouse_definition_id
}
