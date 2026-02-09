# Crée le fichier
#cat > terraform/live/variables.tf << 'TFEOF'
# ============================================================================
# VARIABLES GLOBALES - JobHunt Cloud DevOps Project
# ============================================================================
# Ce fichier contient TOUTES les variables réutilisables
# Tu peux changer les valeurs sans modifier le code Terraform
# ============================================================================

# ============================================================================
# VARIABLES GÉNÉRALES DU PROJET
# ============================================================================

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "jobhunt"
  
  # Explique :
  # Cette variable sera utilisée pour :
  # - jobhunt-rg (Resource Group)
  # - jobhunt-aks (Cluster Kubernetes)
  # - jobhuntacr (Container Registry)
  # - jobhunt-kv (Key Vault)
  # Avantage : change UNE variable = tout est renommé
}

variable "environment" {
  description = "Environnement (dev/staging/prod)"
  type        = string
  default     = "dev"
  
  # Explique :
  # dev = développement (coûts bas, pas de backup excessif)
  # prod = production (sécurité maximale, backup complet)
}

variable "azure_region" {
  description = "Région Azure"
  type        = string
  default     = "France Central"
  
  # Explique :
  # Options principales :
  # "France Central" = Strasbourg (légal RGPD)
  # "North Europe" = Pays-Bas
  # "East US" = moins cher
  # "UK South" = Royaume-Uni
}

variable "azure_region_short" {
  description = "Code court de la région (pour les noms)"
  type        = string
  default     = "frc"
  
  # Explique :
  # frc = France Central
  # neu = North Europe
  # eus = East US
}

# ============================================================================
# VARIABLES KUBERNETES (AKS)
# ============================================================================

variable "aks_node_count" {
  description = "Nombre initial de worker nodes"
  type        = number
  default     = 2
  
  # Explique :
  # 1 = risqué (1 défaillance = tout tombe)
  # 2 = bon compromis (résilience + budget)
  # 3+ = coûteux mais très disponible
}

variable "aks_min_node_count" {
  description = "Nombre minimum de nodes (autoscaling)"
  type        = number
  default     = 1
  
  # Explique :
  # Si pas de charge = scale down à 1 node = économies!
}

variable "aks_max_node_count" {
  description = "Nombre maximum de nodes (autoscaling)"
  type        = number
  default     = 3
  
  # Explique :
  # Si trafic explose = scale up jusqu'à 3 nodes
  # Après = protection (tu ne paies pas plus)
}

variable "aks_vm_size" {
  description = "Taille des VMs Azure"
  type        = string
  default     = "Standard_B2s"
  
  # Explique :
  # Standard_B2s = 2 vCPU, 4GB RAM, ~$50/mois = RECOMMANDÉ
  # Standard_B1s = 1 vCPU, 1GB RAM, ~$18/mois = TOO SMALL
  # Standard_B4ms = 4 vCPU, 16GB RAM, ~$150/mois = TOO EXPENSIVE
}

variable "aks_kubernetes_version" {
  description = "Version Kubernetes"
  type        = string
  default     = "1.29"
  
  # Explique :
  # 1.28, 1.29, 1.30 = stables et supportées
  # Azure gère les updates = tu juste donnes le numéro
}

# ============================================================================
# VARIABLES DATABASE (PostgreSQL)
# ============================================================================

variable "postgres_sku_name" {
  description = "SKU PostgreSQL (Free Tier 12 mois)"
  type        = string
  default     = "B_Standard_B1ms"
  
  # Explique :
  # B_Standard_B1ms = Free Tier 12 mois avec Azure Student!
  # Après : $50/mois
  # Limites : 32GB disque, uptime pas garanti (dev seulement)
}

variable "postgres_version" {
  description = "Version PostgreSQL"
  type        = string
  default     = "14"
  
  # Explique :
  # 13, 14, 15, 16 = bonnes versions
  # Plus nouveau = plus de features, peut-être moins stable
}

variable "postgres_storage_mb" {
  description = "Stockage PostgreSQL en MB"
  type        = number
  default     = 32768
  
  # Explique :
  # 32768 MB = 32 GB (limite Free Tier)
  # À augmenter si besoin
}

variable "postgres_admin_username" {
  description = "Admin username DB"
  type        = string
  sensitive   = true
  default     = "dbadmin"
  
  # Explique :
  # sensitive = true = Terraform cache la valeur dans les logs
  # Exemple : terraform apply → "password = <sensitive>"
  # Et non "password = abc123"
}

# ============================================================================
# VARIABLES CONTAINER REGISTRY (ACR)
# ============================================================================

variable "acr_sku" {
  description = "Tier ACR"
  type        = string
  default     = "Basic"
  
  # Explique :
  # Basic = $5/mois (PARFAIT pour étudiant)
  # Standard = $25/mois
  # Premium = $250/mois (production seulement)
}

variable "acr_admin_enabled" {
  description = "Activer accès admin ACR"
  type        = bool
  default     = false
  
  # Explique :
  # false = utiliser RBAC (sécurité)
  # true = clés d'accès simples (moins sûr)
}

# ============================================================================
# VARIABLES RÉSEAU
# ============================================================================

variable "vnet_address_space" {
  description = "CIDR du VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
  
  # Explique :
  # 10.0.0.0/16 = ~65000 IPs (10.0.0.0 à 10.0.255.255)
  # Assez pour tes pods et services
}

variable "aks_subnet_address_prefix" {
  description = "CIDR subnet AKS"
  type        = list(string)
  default     = ["10.0.1.0/24"]
  
  # Explique :
  # /24 = ~250 IPs (10.0.1.0 à 10.0.1.255)
  # Assez pour tes pods
}

variable "database_subnet_address_prefix" {
  description = "CIDR subnet Database"
  type        = list(string)
  default     = ["10.0.2.0/24"]
  
  # Explique :
  # Subnet séparé pour la DB = isolation de sécurité
}

# ============================================================================
# VARIABLES MONITORING & LOGS
# ============================================================================

variable "log_retention_days" {
  description = "Jours de rétention logs"
  type        = number
  default     = 7
  
  # Explique :
  # 7 jours = logs supprimés auto après 7 jours
  # Économise de l'argent (logs coûtent par GB)
  # 30+ jours = production seulement
}

variable "enable_advanced_monitoring" {
  description = "Prometheus/Grafana avancé?"
  type        = bool
  default     = false
  
  # Explique :
  # false = Azure Monitor basique (moins cher)
  # true = Prometheus/Grafana en plus (plus cher, meilleures alerts)
}

# ============================================================================
# VARIABLES TAGS (TRÈS IMPORTANT POUR LA FACTURATION)
# ============================================================================

variable "tags" {
  description = "Tags appliqués à TOUTES les ressources"
  type        = map(string)
  default = {
    Project     = "JobHunt"
    Environment = "Dev"
    CreatedBy   = "Terraform"
    CostCenter  = "Education"
    Owner       = "Jiheddridi"
    StartDate   = "2025-01-15"
  }
  
  # Explique :
  # Tags = étiquettes pour :
  # 1. Facturation (voir coûts par tag)
  # 2. Organisation (retrouver les ressources)
  # 3. Compliance (qui a créé quoi, quand)
  # 
  # Dans Azure Portal tu peux :
  # Filtrer : "Montre-moi tous les coûts du tag Project=JobHunt"
}

# ============================================================================
# VARIABLES SÉCURITÉ & BUDGET
# ============================================================================

variable "monthly_budget_usd" {
  description = "Budget mensuel en USD"
  type        = number
  default     = 100
  
  # Explique :
  # Azure Student = $100 de crédit gratuit
  # Faut bien surveiller pour pas dépasser!
  # Commande : az costmanagement query create --budget-name jobhunt-budget
}

variable "enable_network_policy" {
  description = "Activer Network Policies Kubernetes?"
  type        = bool
  default     = true
  
  # Explique :
  # true = pare-feu entre pods (sécurité)
  # false = tous les pods peuvent se parler (moins sûr)
}

variable "enable_rbac" {
  description = "Activer RBAC Kubernetes?"
  type        = bool
  default     = true
  
  # Explique :
  # true = contrôle d'accès basé sur les rôles
  # false = accès libre (dangereux!)
}

#TFEOF

# Vérifie le fichier
#cat terraform/live/variables.tf | head -50
# Output : les 50 premières lignes du fichier
