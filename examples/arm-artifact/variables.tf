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
}

variable "artifact_version" {
  type        = string
  description = "Immutable, storage-path-safe artifact version."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.artifact_version))
    error_message = "artifact_version must start with an alphanumeric character and contain only alphanumeric characters, dots, underscores, or hyphens."
  }
}

variable "customer_key" {
  type        = string
  description = "Non-sensitive, storage-safe customer identifier."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.customer_key))
    error_message = "customer_key must contain only lowercase letters, numbers, and hyphens."
  }
}
