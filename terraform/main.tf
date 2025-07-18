terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "=3.0.0"
    }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "simple-webapp-rg"
  location = var.location
}

resource "azurerm_storage_account" "storage" {
  name                     = "webappstatic${random_id.rand.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_id" "rand" {
  byte_length = 4
}

resource "azurerm_virtual_network" "vnet" {
  name                = "webapp-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "webapp-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "mysql-delegation"

    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "webapp-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "webapp-ipcfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webapp_public_ip.id
  }
}

resource "azurerm_public_ip" "webapp_public_ip" {
  name                = "webapp-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "webapp_vm" {
  name                  = "webapp-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "webapp-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "null_resource" "provision_app" {
  depends_on = [azurerm_linux_virtual_machine.webapp_vm]

  connection {
    type        = "ssh"
    user        = var.admin_username
    password    = var.admin_password
    host        = azurerm_public_ip.webapp_public_ip.ip_address
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "ansible"  # this is your local ansible folder
    destination = "/home/${var.admin_username}/ansible"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y nodejs npm git",
      "sudo apt install -y software-properties-common",
      "sudo apt install -y ansible",
      "cd /home/${var.admin_username}/ansible",
      "ansible-playbook -i inventory playbook.yml"
    ]
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = "webapp-mysql-${random_id.rand.hex}"
  location               = var.location
  resource_group_name    = azurerm_resource_group.rg.name
  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password
  sku_name               = "B_Standard_B1ms"
  version                = "5.7"
  zone                   = "1"
  backup_retention_days  = 7
  delegated_subnet_id = azurerm_subnet.subnet.id
  private_dns_zone_id = null

  depends_on = [azurerm_subnet.subnet]
}

resource "azurerm_mysql_flexible_database" "chatdb" {
  name                = "chatdb"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_network_security_group" "webapp_nsg" {
  name                = "webapp-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Host"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "webapp_nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.webapp_nsg.id
}