module "native" {
  count = var.deployment_mode == "terraform" ? 1 : 0

  source = "./modules/native"

  scope                 = var.scope
  normalized_delegation = local.normalized_delegation
}
