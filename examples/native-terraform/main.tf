module "lighthouse" {
  source = "../.."

  artifact_version = var.artifact_version
  deployment_mode  = "terraform"
  scope            = "/subscriptions/${var.customer_subscription_id}"

  delegation = merge(var.delegation, {
    managing_tenant_id = var.managing_tenant_id
  })
}
