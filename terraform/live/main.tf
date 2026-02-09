# ============================================================================
# JOBHUNT TERRAFORM - FINAL CORRECTED VERSION
# ============================================================================

# ============================================================================
# RESOURCE GROUP
# ============================================================================

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.azure_region
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-rg"
    }
  )
}

# ============================================================================
# VIRTUAL NETWORK
# ============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = var.vnet_address_space
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  
  tags = var.tags
}

# ============================================================================
# SUBNETS
# ============================================================================

resource "azurerm_subnet" "aks" {
  name                 = "${var.project_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_address_prefix
}

resource "azurerm_subnet" "database" {
  name                 = "${var.project_name}-db-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.database_subnet_address_prefix
  
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }
}

# ============================================================================
# NETWORK SECURITY GROUP
# ============================================================================

resource "azurerm_network_security_group" "aks" {
  name                = "${var.project_name}-aks-nsg"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "AllowKubernetesAPI"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
  
  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# ============================================================================
# MANAGED IDENTITY
# ============================================================================

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.project_name}-aks-identity"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
}

# ============================================================================
# RANDOM STRINGS
# ============================================================================

resource "random_string" "workspace_suffix" {
  length  = 4
  special = false
}

resource "random_string" "kv_suffix" {
  length  = 4
  special = false
}

# ============================================================================
# LOG ANALYTICS
# ============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "jobhunt-logs-${random_string.workspace_suffix.result}"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  
  sku               = "PerGB2018"
  retention_in_days = 30
  
  tags = var.tags
}

# ============================================================================
# APPLICATION INSIGHTS
# ============================================================================

resource "azurerm_application_insights" "main" {
  name                = "${var.project_name}-ai"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  
  workspace_id = azurerm_log_analytics_workspace.main.id
  
  tags = var.tags
}

# ============================================================================
# KUBERNETES CLUSTER (AKS) - VERSION 1.30
# ============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-aks"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.project_name
  
  kubernetes_version = "1.34"
  
  default_node_pool {
    name                = "default"
    node_count          = var.aks_node_count
    vm_size             = var.aks_vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    
    enable_auto_scaling = true
    min_count          = var.aks_min_node_count
    max_count          = var.aks_max_node_count
    
    type                = "VirtualMachineScaleSets"
    os_disk_size_gb     = 30
  }
  
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }
  
  network_profile {
    network_plugin     = "azure"
    network_policy     = var.enable_network_policy ? "azure" : "none"
    load_balancer_sku  = "standard"
  service_cidr       = "10.100.0.0/16"
  dns_service_ip     = "10.100.0.10"
  }
  
  role_based_access_control_enabled = var.enable_rbac

  # OIDC Issuer (required by Azure)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }
  
  tags = var.tags
  
  depends_on = [azurerm_resource_group.main]
}

# ============================================================================
# CONTAINER REGISTRY (ACR)
# ============================================================================

resource "azurerm_container_registry" "main" {
  name                = "${replace(var.project_name, "-", "")}acr"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  
  sku           = var.acr_sku
  admin_enabled = false
  
  tags = var.tags
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope              = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id       = azurerm_user_assigned_identity.aks.principal_id
}

# ============================================================================
# PRIVATE DNS ZONE - CORRECT
# ============================================================================

resource "azurerm_private_dns_zone" "postgres" {
  name                = "jobhunt.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  
  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.project_name}-postgres-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
  resource_group_name   = azurerm_resource_group.main.name
}

# ============================================================================
# POSTGRESQL DATABASE
# ============================================================================

resource "random_password" "postgres_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project_name}-db"
  location               = var.azure_region
  resource_group_name    = azurerm_resource_group.main.name
  
  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.postgres_password.result
  
  sku_name            = var.postgres_sku_name
  version             = var.postgres_version
  delegated_subnet_id = azurerm_subnet.database.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  
  storage_mb = var.postgres_storage_mb
  
  zone                          = "1"
  
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  
  public_network_access_enabled = false
  
  tags = var.tags
  
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "jobs" {
  name      = "jobs"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ============================================================================
# KEY VAULT
# ============================================================================

resource "azurerm_key_vault" "main" {
  name                        = "${var.project_name}-kv-${random_string.kv_suffix.result}"
  location                    = var.azure_region
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    secret_permissions = [
      "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
    ]
  }
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.aks.principal_id
    
    secret_permissions = ["Get", "List"]
  }
  
  tags = var.tags
}

# ============================================================================
# KEY VAULT SECRETS
# ============================================================================

resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "database-connection-string"
  value        = "postgresql://${var.postgres_admin_username}:${random_password.postgres_password.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/jobs"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "database-admin-password"
  value        = random_password.postgres_password.result
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "acr_login_server" {
  name         = "acr-login-server"
  value        = azurerm_container_registry.main.login_server
  key_vault_id = azurerm_key_vault.main.id
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_kubectl_configure_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.main.login_server
}

output "database_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
  description = "Database name"
  value       = azurerm_postgresql_flexible_server_database.jobs.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}
