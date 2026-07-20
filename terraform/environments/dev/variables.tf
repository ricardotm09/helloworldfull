variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rx-rg-aks-dev"
}

variable "location" {
  description = "Azure region for the resources"
  type        = string
  default     = "eastus"
}

variable "acr_name" {
  description = "Prefix for the Azure Container Registry name. A unique suffix will be added automatically."
  type        = string
  default     = "rx-acr-aks"
}

variable "aks_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "rx-aks-dev"
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "rx-aks-dev"
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

variable "state_resource_group_name" {
  description = "Resource group that contains the Terraform state storage account"
  type        = string
  default     = "rx-terraform-rg"
}

variable "state_storage_account_name" {
  description = "Storage account name used for Terraform remote state"
  type        = string
  default     = "terraform87"
}

variable "state_container_name" {
  description = "Blob container name for Terraform remote state"
  type        = string
  default     = "terraform"
}

variable "state_key" {
  description = "State file key name"
  type        = string
  default     = "dev.terraform.tfstate"
}
