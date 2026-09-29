output "lighthouse_assignment_id" {
  description = "Fully qualified Azure Lighthouse assignment resource ID."
  value       = azurerm_lighthouse_assignment.this.id
}

output "lighthouse_definition_id" {
  description = "Fully qualified Azure Lighthouse definition resource ID."
  value       = azurerm_lighthouse_definition.this.id
}
