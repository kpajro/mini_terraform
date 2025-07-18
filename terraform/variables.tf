variable "location" {
  default = "northeurope"
}

variable "admin_username" {
  default = "azureuser"
}

variable "admin_password" {
  description = "Password for the VM"
  sensitive   = true
}