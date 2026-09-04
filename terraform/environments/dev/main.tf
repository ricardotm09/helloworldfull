terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-87"
    storage_account_name = "tfstate87"
    container_name       = "terraform"
    key                  = "dev.terraform.tfstate"
    use_azuread_auth     = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  acr_name = substr(lower("${var.acr_name}${random_string.acr_suffix.result}"), 0, 50)
}

data "azurerm_monitor_diagnostic_categories" "aks" {
  resource_id = azurerm_kubernetes_cluster.aks.id
}

data "azurerm_monitor_diagnostic_categories" "acr" {
  resource_id = azurerm_container_registry.acr.id
}

resource "random_string" "acr_suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "platform" {
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_in_days

  tags = var.tags
}

resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.aks_dns_prefix
  oidc_issuer_enabled = true

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id
  }

  default_node_pool {
    name       = "system"
    node_count = var.aks_node_count
    vm_size    = var.aks_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    load_balancer_sku = "standard"
    network_plugin    = "azure"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.aks_name}-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.aks.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.aks.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${azurerm_container_registry.acr.name}-diagnostics"
  target_resource_id         = azurerm_container_registry.acr.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.acr.log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.acr.metrics)
    content {
      category = metric.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_action_group" "platform" {
  count               = var.monitor_alert_email_address != "" ? 1 : 0
  name                = "${var.aks_name}-alerts"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "opsalert"

  email_receiver {
    name                    = "platform-email"
    email_address           = var.monitor_alert_email_address
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "acr_storage_used_high" {
  name                = "${azurerm_container_registry.acr.name}-storage-used-high"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_container_registry.acr.id]
  description         = "Alert when Azure Container Registry storage usage exceeds the configured threshold."
  severity            = 3
  enabled             = true
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerRegistry/registries"
    metric_name      = "StorageUsed"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.acr_storage_used_threshold_bytes
  }

  dynamic "action" {
    for_each = azurerm_monitor_action_group.platform[*]
    content {
      action_group_id = action.value.id
    }
  }
}

resource "azurerm_monitor_activity_log_alert" "aks_write_failure" {
  name                = "${var.aks_name}-write-failure"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "global"
  scopes              = [azurerm_kubernetes_cluster.aks.id]
  description         = "Alert when AKS control plane write operations fail in Azure activity logs."

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.ContainerService/managedClusters/write"
    level          = "Error"
    status         = "Failed"
  }

  dynamic "action" {
    for_each = azurerm_monitor_action_group.platform[*]
    content {
      action_group_id = action.value.id
    }
  }
}
