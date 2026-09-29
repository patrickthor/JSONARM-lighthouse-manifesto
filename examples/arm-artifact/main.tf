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
  for_each = var.customers

  source = "../.."

  # The dual-mode module needs an AzureRM configuration, but ARM rendering does
  # not query or authenticate to any customer subscription. Reuse the separate
  # artifact-storage provider rather than introducing a customer provider here.
  providers = {
    azurerm = azurerm.artifacts
  }

  artifact_version = var.artifact_version
  deployment_mode  = "arm"
  scope            = null

  delegation = merge(each.value, {
    managing_tenant_id = var.managing_tenant_id
  })
}

resource "azurerm_storage_blob" "lighthouse" {
  for_each = module.lighthouse

  provider = azurerm.artifacts

  name                 = "lighthouse-artifacts/${each.key}/${var.artifact_version}/lighthouse.json"
  storage_container_id = data.azurerm_storage_container.artifacts.id
  type                 = "Block"
  content_type         = "application/json"
  source_content       = each.value.arm_template_json
}
