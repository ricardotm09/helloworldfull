variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-aks-dev"
}

variable "location" {
  description = "Azure region for the resources"
  type        = string
  default     = "eastus"
}

variable "acr_name_prefix" {
  description = "Prefix for the Azure Container Registry name. A unique suffix will be added automatically."
  type        = string
  default     = "acraks"
}

variable "aks_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-dev"
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "aks-dev"
}

variable "aks_node_count" {
  description = "Number of nodes in the default AKS node pool"
  type        = number
  default     = 1
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "tags" {
  description = "Tags to apply to the resources"
  type        = map(string)
  default = {
    environment = "dev"
    project     = "helloworldfull"
  }
}
