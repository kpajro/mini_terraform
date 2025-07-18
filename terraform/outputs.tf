output "public_ip" {
  value = azurerm_public_ip.webapp_public_ip.ip_address
}

output "public_ip_address" {
  value = data.azurerm_public_ip.webapp_ip.ip_address
}