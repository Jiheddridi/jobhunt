#cat > terraform/live/provider.tf << 'TFEOF'
# ============================================================================
# TERRAFORM PROVIDERS CONFIGURATION
# ============================================================================
# Déclare les providers (plugins) qu'on va utiliser
# Dans notre cas : Azure + Random (pour des valeurs aléatoires)
# ============================================================================

terraform {
  required_version = ">= 1.0"
  
  # Explique :
  # required_version >= 1.0 = Terraform doit être version 1.0 ou plus
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
      
      # Explique :
      # source = où trouver le provider (registre officiel)
      # version ~> 3.90 = version 3.x (pas 4.x qui pourrait être incompatible)
      # ~> = "3.x mais pas 4.0" (contrainte de version)
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
      
      # Explique :
      # Pour générer des valeurs aléatoires
      # Exemple : suffix random pour les noms (jobhunt-kv-abc123)
    }
  }
}

# ============================================================================
# AZURE PROVIDER CONFIGURATION
# ============================================================================

provider "azurerm" {
  features {}
  
  # Explique :
  # features {} = active toutes les features par défaut d'Azure
  # On ne change rien = utiliser les defaults (c'est bon)
  #
  # Comment l'authentification fonctionne :
  # 1. Tu as fait "az login" sur ton PC
  # 2. Azure a sauvé tes credentials dans ~/.azure/
  # 3. Terraform dit "Az login existe? Oui → j'utilise ça"
  # 4. Terraform se connecte à Azure automatiquement
}

provider "random" {
  # Pas de configuration spéciale pour random
}

# ============================================================================
# DATA SOURCE : Récupère infos du compte Azure
# ============================================================================
# Data source = récupérer des infos qui existent déjà
# Exemple : infos sur le compte Azure

data "azurerm_client_config" "current" {
  # Cette data source récupère :
  # - tenant_id = ID du tenant Azure
  # - subscription_id = ID de ta souscription
  # - object_id = ID de ton utilisateur
  # - client_id = ID du client
  #
  # Très utile pour les policies et RBAC
}

# ============================================================================
# OUTPUTS : Exporte les infos importantes
# ============================================================================

output "current_subscription_id" {
  description = "ID de ta souscription Azure"
  value       = data.azurerm_client_config.current.subscription_id
  
  # Explique :
  # Après "terraform apply", affiche l'ID de ta souscription
  # Utile pour vérifier que tu es connecté au bon compte
}

output "current_tenant_id" {
  description = "ID du tenant Azure"
  value       = data.azurerm_client_config.current.tenant_id
}

output "current_object_id" {
  description = "Object ID de ton utilisateur (pour RBAC)"
  value       = data.azurerm_client_config.current.object_id
}

#TFEOF

#cat terraform/live/provider.tf
