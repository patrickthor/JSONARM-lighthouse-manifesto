variable "artifact_version" {
  type        = string
  description = "Immutable consumer-defined version included in the suggested ARM artifact filename."

  validation {
    condition     = trimspace(var.artifact_version) != ""
    error_message = "artifact_version must not be empty."
  }
}

variable "delegation" {
  type = object({
    offer_name         = string
    offer_description  = optional(string, "")
    managing_tenant_id = string

    principals = map(object({
      principal_id    = string
      principal_name  = string
      permanent_roles = optional(set(string), [])

      eligible_roles = optional(map(object({
        maximum_activation_duration = string
        require_mfa                 = optional(bool, true)
        approvers = optional(list(object({
          principal_id   = string
          principal_name = string
        })), [])
      })), {})
    }))
  })
  description = "Customer-specific Azure Lighthouse offer, principals, permanent roles, and eligible role policies. Principal map keys must be stable consumer-defined identifiers."

  validation {
    condition     = trimspace(var.delegation.offer_name) != ""
    error_message = "delegation.offer_name must not be empty."
  }

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.delegation.managing_tenant_id))
    error_message = "delegation.managing_tenant_id must be a UUID-shaped string."
  }

  validation {
    condition = alltrue([
      for principal_key in keys(var.delegation.principals) :
      can(regex("^[A-Za-z0-9][A-Za-z0-9_-]*$", principal_key))
    ])
    error_message = "Every delegation.principals map key must start with an alphanumeric character and contain only alphanumeric characters, underscores, or hyphens."
  }

  validation {
    condition = alltrue([
      for principal in values(var.delegation.principals) :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", principal.principal_id))
    ])
    error_message = "Every principal_id must be a UUID-shaped string."
  }

  validation {
    condition = alltrue([
      for principal in values(var.delegation.principals) :
      trimspace(principal.principal_name) != ""
    ])
    error_message = "Every principal_name must not be empty."
  }

  validation {
    condition = alltrue([
      for principal in values(var.delegation.principals) :
      length(principal.permanent_roles) + length(principal.eligible_roles) > 0
    ])
    error_message = "Every principal must request at least one permanent or eligible role."
  }

  validation {
    condition = sum([
      for principal in values(var.delegation.principals) :
      length(principal.permanent_roles) + length(principal.eligible_roles)
    ]) > 0
    error_message = "At least one Lighthouse authorization must be configured."
  }

  validation {
    condition = alltrue(flatten([
      for principal in values(var.delegation.principals) : [
        for role_name in concat(tolist(principal.permanent_roles), keys(principal.eligible_roles)) :
        contains([
          "Reader",
          "Contributor",
          "Managed Services Registration Assignment Delete Role"
        ], role_name)
      ]
    ]))
    error_message = "Every requested role must be in the module allowlist: Reader, Contributor, or Managed Services Registration Assignment Delete Role."
  }

  validation {
    condition = alltrue([
      for principal in values(var.delegation.principals) :
      length(principal.eligible_roles) == 0 || contains(principal.permanent_roles, "Reader")
    ])
    error_message = "Every principal with an eligible role must also have an explicit permanent Reader authorization."
  }

  validation {
    condition = alltrue(flatten([
      for principal in values(var.delegation.principals) : [
        for policy in values(principal.eligible_roles) :
        contains([
          "PT30M",
          "PT1H",
          "PT1H30M",
          "PT2H",
          "PT2H30M",
          "PT3H",
          "PT3H30M",
          "PT4H",
          "PT4H30M",
          "PT5H",
          "PT5H30M",
          "PT6H",
          "PT6H30M",
          "PT7H",
          "PT7H30M",
          "PT8H"
        ], policy.maximum_activation_duration)
      ]
    ]))
    error_message = "Every eligible role duration must be a half-hour increment from PT30M through PT8H."
  }

  validation {
    condition = alltrue(flatten([
      for principal in values(var.delegation.principals) : [
        for policy in values(principal.eligible_roles) :
        length(policy.approvers) <= 10
      ]
    ]))
    error_message = "An eligible authorization can have at most 10 approvers."
  }

  validation {
    condition = alltrue(flatten([
      for principal in values(var.delegation.principals) : [
        for policy in values(principal.eligible_roles) : [
          for approver in policy.approvers :
          can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", approver.principal_id))
        ]
      ]
    ]))
    error_message = "Every approver principal_id must be a UUID-shaped string."
  }

  validation {
    condition = alltrue(flatten([
      for principal in values(var.delegation.principals) : [
        for policy in values(principal.eligible_roles) : [
          for approver in policy.approvers :
          trimspace(approver.principal_name) != ""
        ]
      ]
    ]))
    error_message = "Every approver principal_name must not be empty."
  }

  validation {
    condition = alltrue(flatten([
      for principal in values(var.delegation.principals) : [
        for policy in values(principal.eligible_roles) : [
          for approver in policy.approvers :
          lower(approver.principal_id) != lower(principal.principal_id)
        ]
      ]
    ]))
    error_message = "An eligible principal cannot approve its own role activation."
  }

  validation {
    condition = alltrue([
      for role_name in [
        "Reader",
        "Contributor",
        "Managed Services Registration Assignment Delete Role"
        ] : length(distinct(flatten([
          for principal in values(var.delegation.principals) : [
            for requested_role, policy in principal.eligible_roles : jsonencode({
              maximum_activation_duration = policy.maximum_activation_duration
              require_mfa                 = policy.require_mfa
              approvers = sort([
                for approver in policy.approvers :
                jsonencode({
                  principal_id   = lower(approver.principal_id)
                  principal_name = trimspace(approver.principal_name)
                })
              ])
            }) if requested_role == role_name
          ]
      ]))) <= 1
    ])
    error_message = "All eligible authorizations for the same role must use identical duration, MFA, and approver settings."
  }

  validation {
    condition = length(flatten([
      for principal in values(var.delegation.principals) : [
        for role_name in principal.permanent_roles :
        "${lower(principal.principal_id)}/${role_name}"
      ]
      ])) == length(distinct(flatten([
        for principal in values(var.delegation.principals) : [
          for role_name in principal.permanent_roles :
          "${lower(principal.principal_id)}/${role_name}"
        ]
    ])))
    error_message = "Duplicate permanent principal/role pairs are not allowed, including duplicates under different principal map keys."
  }

  validation {
    condition = length(flatten([
      for principal in values(var.delegation.principals) : [
        for role_name in keys(principal.eligible_roles) :
        "${lower(principal.principal_id)}/${role_name}"
      ]
      ])) == length(distinct(flatten([
        for principal in values(var.delegation.principals) : [
          for role_name in keys(principal.eligible_roles) :
          "${lower(principal.principal_id)}/${role_name}"
        ]
    ])))
    error_message = "Duplicate eligible principal/role pairs are not allowed, including duplicates under different principal map keys."
  }

  validation {
    condition = length(setintersection(
      toset(flatten([
        for principal in values(var.delegation.principals) : [
          for role_name in principal.permanent_roles :
          "${lower(principal.principal_id)}/${role_name}"
        ]
      ])),
      toset(flatten([
        for principal in values(var.delegation.principals) : [
          for role_name in keys(principal.eligible_roles) :
          "${lower(principal.principal_id)}/${role_name}"
        ]
      ]))
    )) == 0
    error_message = "The same principal/role pair cannot be both permanent and eligible."
  }
}

variable "deployment_mode" {
  type        = string
  description = "Delivery path: terraform creates the Lighthouse resources; arm only renders the self-contained ARM template."

  validation {
    condition     = contains(["terraform", "arm"], var.deployment_mode)
    error_message = "deployment_mode must be exactly \"terraform\" or \"arm\"."
  }
}

variable "scope" {
  type        = string
  description = "Customer subscription resource ID used only for native Terraform deployment."
  default     = null
  nullable    = true

  validation {
    condition = var.scope == null ? true : can(regex(
      "^/subscriptions/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
      var.scope
    ))
    error_message = "scope must be null or a subscription resource ID in the form /subscriptions/<uuid>."
  }

  validation {
    condition     = var.deployment_mode == "terraform" ? var.scope != null : true
    error_message = "scope is required when deployment_mode is \"terraform\"."
  }

  validation {
    condition     = var.deployment_mode == "arm" ? var.scope == null : true
    error_message = "scope must be null when deployment_mode is \"arm\" because the customer selects the target subscription during portal deployment."
  }
}
