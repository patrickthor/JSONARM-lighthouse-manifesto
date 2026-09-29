output "arm_template_sha256" {
  description = "SHA-256 checksums keyed by stable customer key."
  value = {
    for customer_key, lighthouse in module.lighthouse :
    customer_key => lighthouse.arm_template_sha256
  }
}

output "blob_urls" {
  description = "Private blob URLs keyed by customer. These are not SAS URLs and grant no access by themselves."
  value = {
    for customer_key, blob in azurerm_storage_blob.lighthouse :
    customer_key => blob.url
  }
}

output "suggested_artifact_names" {
  description = "Suggested local artifact filenames keyed by customer."
  value = {
    for customer_key, lighthouse in module.lighthouse :
    customer_key => lighthouse.suggested_artifact_name
  }
}
