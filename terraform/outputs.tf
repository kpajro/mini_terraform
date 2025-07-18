output "public_ip" {
  value = azurerm_public_ip.webapp_public_ip.ip_address
}

output "mysql_connection_string" {
  value = "mysql://${var.mysql_admin_username}:${var.mysql_admin_password}@${azurerm_mysql_flexible_server.mysql.fqdn}:3306/chatdb"
  sensitive = true
}