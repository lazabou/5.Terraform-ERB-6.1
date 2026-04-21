terraform {
  required_providers {
    apstra = {
      source  = "Juniper/apstra"
      version = "0.99.0"
    }
  }
}

variable "apstra_url" {
  type = string
}



provider "apstra" {
  url = var.apstra_url

  tls_validation_disabled = true
  blueprint_mutex_enabled = false
  experimental            = true
}


