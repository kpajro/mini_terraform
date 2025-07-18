variable "location" {
  default = "East US"
}

variable "admin_username" {
  default = "azureuser"
}

variable "admin_password" {
  description = "Password for the VM"
  sensitive   = true
}

variable "mysql_admin_username" {
  default = "mysqladmin"
}

variable "mysql_admin_password" {
  description = "Password for MySQL admin user"
  sensitive   = true
}