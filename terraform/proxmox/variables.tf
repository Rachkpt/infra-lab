variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox, ex: https://192.168.x.x:8006"
  type        = string
}

variable "proxmox_api_token" {
  description = "Token API Proxmox, format terraform-prov@pve!terraform=<secret>"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Nom du noeud Proxmox"
  type        = string
  default     = "pve"
}

variable "template_vm_id" {
  description = "ID du template cloud-init Ubuntu (cree en Phase 0)"
  type        = number
  default     = 9000
}

variable "datastore_id" {
  description = "Datastore Proxmox utilise pour les disques"
  type        = string
  default     = "local-lvm"
}
