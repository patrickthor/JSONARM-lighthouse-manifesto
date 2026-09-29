provider "azurerm" {
  alias = "artifacts"

  features {}

  subscription_id = var.artifact_storage_subscription_id
}
