output "arm_template_json" {
  description = "Self-contained subscription-scope ARM template JSON. Do not deploy it if Terraform already manages the same delegation."
  value       = local.arm_template_json
}

output "arm_template_sha256" {
  description = "SHA-256 checksum of exactly arm_template_json."
  value       = sha256(local.arm_template_json)
}

output "lighthouse_assignment_id" {
  description = "Native Lighthouse assignment resource ID in terraform mode; null in arm mode."
  value       = try(module.native[0].lighthouse_assignment_id, null)
}

output "lighthouse_definition_id" {
  description = "Native Lighthouse definition resource ID in terraform mode; null in arm mode."
  value       = try(module.native[0].lighthouse_definition_id, null)
}

output "normalized_delegation" {
  description = "Non-sensitive canonical delegation model consumed by both renderers."
  value       = local.normalized_delegation
}

output "suggested_artifact_name" {
  description = "Safe deterministic ARM artifact filename derived from the offer name and artifact version."
  value       = local.suggested_artifact_name
}
