variable "artifact_storage_account_name" {
  type        = string
  description = "Name of the existing artifact storage account."
}

variable "artifact_storage_container_name" {
  type        = string
  description = "Name of the existing private artifact container. Do not use the Terraform-state container."
}

variable "artifact_storage_resource_group_name" {
  type        = string
  description = "Resource group containing the existing artifact storage account."
}

variable "artifact_storage_subscription_id" {
  type        = string
  description = "Subscription containing the existing artifact storage account."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.artifact_storage_subscription_id))
    error_message = "artifact_storage_subscription_id must be a UUID-shaped string."
  }
}

variable "artifact_version" {
  type        = string
  description = "Immutable, storage-path-safe artifact version supplied by the release workflow."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.artifact_version))
    error_message = "artifact_version must start with an alphanumeric character and contain only alphanumeric characters, dots, underscores, or hyphens."
  }
}

variable "customers" {
  type        = any
  description = "Committed governance map keyed by stable, storage-safe customer key. The Lighthouse module owns the nested delegation schema and validation."

  validation {
    condition     = length(var.customers) > 0
    error_message = "customers must contain at least one customer delegation."
  }

  validation {
    condition = alltrue([
      for customer_key in keys(var.customers) :
      can(regex("^[a-z0-9][a-z0-9-]*$", customer_key))
    ])
    error_message = "Every customer key must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "managing_tenant_id" {
  type        = string
  description = "Shared service-provider tenant ID supplied at runtime rather than repeated in the governance record."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.managing_tenant_id))
    error_message = "managing_tenant_id must be a UUID-shaped string."
  }
}
