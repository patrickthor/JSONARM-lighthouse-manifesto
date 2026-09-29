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
  alias = "artifacts"

  features {}

  subscription_id = var.artifact_storage_subscription_id
}

data "azurerm_storage_account" "artifacts" {
  provider = azurerm.artifacts

  name                = var.artifact_storage_account_name
  resource_group_name = var.artifact_storage_resource_group_name
}

data "azurerm_storage_container" "artifacts" {
  provider = azurerm.artifacts

  name               = var.artifact_storage_container_name
  storage_account_id = data.azurerm_storage_account.artifacts.id
}

module "lighthouse" {
  source = "../.."

  # Terraform requires a configured AzureRM provider for this dual-mode module,
  # but ARM rendering does not query or authenticate to the customer subscription.
  providers = {
    azurerm = azurerm.artifacts
  }

  artifact_version = var.artifact_version
  deployment_mode  = "arm"
  scope            = null

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

resource "azurerm_storage_blob" "lighthouse" {
  provider = azurerm.artifacts

  name                 = "lighthouse-artifacts/${var.customer_key}/${var.artifact_version}/lighthouse.json"
  storage_container_id = data.azurerm_storage_container.artifacts.id
  type                 = "Block"
  content_type         = "application/json"
  source_content       = module.lighthouse.arm_template_json
}

output "arm_template_sha256" {
  value = module.lighthouse.arm_template_sha256
}

output "blob_url" {
  description = "Private blob URL. This is not a SAS URL and grants no access by itself."
  value       = azurerm_storage_blob.lighthouse.url
}

output "suggested_artifact_name" {
  value = module.lighthouse.suggested_artifact_name
}
