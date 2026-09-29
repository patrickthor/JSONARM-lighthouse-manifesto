variable "artifact_version" {
  type        = string
  description = "Artifact version supplied at runtime. ARM JSON remains available for inspection even in native mode."
}

variable "customer_subscription_id" {
  type        = string
  description = "Customer subscription governed by this root and state."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.customer_subscription_id))
    error_message = "customer_subscription_id must be a UUID-shaped string."
  }
}

variable "delegation" {
  type        = any
  description = "Committed customer delegation. The Lighthouse module owns its detailed schema and validation."
}

variable "managing_tenant_id" {
  type        = string
  description = "Shared service-provider tenant ID supplied at runtime."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.managing_tenant_id))
    error_message = "managing_tenant_id must be a UUID-shaped string."
  }
}

variable "provider_subscription_id" {
  type        = string
  description = "Runtime AzureRM provider subscription. It must match the committed customer subscription for this one-customer state."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.provider_subscription_id))
    error_message = "provider_subscription_id must be a UUID-shaped string."
  }

  validation {
    condition     = lower(var.provider_subscription_id) == lower(var.customer_subscription_id)
    error_message = "provider_subscription_id must match the committed customer_subscription_id so the provider, scope, and state refer to the same customer subscription."
  }
}
