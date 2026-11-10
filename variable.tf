variable "subscription_id" {
  type        = string
  description = "ID de l'abonnement Azure, defini uniquement dans terraform.tfvars"
  nullable    = true
  default     = null
}

variable "nom" {
  type        = string
  description = "Identifiant du binome utilise dans les noms et tags Azure"
}

variable "env" {
  type        = string
  description = "Environnement de deploiement"
  default     = "dev"
}

variable "region" {
  type        = string
  description = "Region Azure retenue pour le TP"
  default     = "spaincentral"
}

variable "binome" {
  type        = number
  description = "Numero de groupe, utilise pour construire le reseau 10.numgroupe.0.0/16"

  validation {
    condition     = var.binome >= 1 && var.binome <= 254 && floor(var.binome) == var.binome
    error_message = "Le numero de groupe doit etre un entier compris entre 1 et 254."
  }
}

variable "vm_size" {
  type        = string
  description = "Taille des VM web retenue pendant le TP Azure"
  default     = "Standard_B1s"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Chemin local vers la cle publique SSH utilisee pour les VM web"
}

variable "ssh_allowed_ip" {
  type        = string
  description = "Adresse IP publique autorisee a se connecter en SSH a la jumpbox, au format CIDR (exemple 203.0.113.10/32)"

  validation {
    condition     = can(cidrhost(var.ssh_allowed_ip, 0))
    error_message = "ssh_allowed_ip doit etre une adresse IPv4 au format CIDR, par exemple 203.0.113.10/32."
  }
}

variable "admin_username" {
  type        = string
  description = "Nom de l'utilisateur Linux cree sur les VM web"
  default     = "azureuser"
}
