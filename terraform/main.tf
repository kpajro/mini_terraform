terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.105.0"
    }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "simple-webapp-rg"
  location = var.location
}

resource "azurerm_storage_account" "storage" {
  name                     = "webappstatic"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "webapp-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# VM subnet
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# MySQL subnet with delegation
resource "azurerm_subnet" "mysql_subnet" {
  name                 = "mysql-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

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

resource "azurerm_public_ip" "webapp_public_ip" {
  name                = "webapp-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "nic" {
  name                = "webapp-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "webapp-ipcfg"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webapp_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "webapp_vm" {
  name                            = "webapp-vm"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]
  
  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/terraform_key.pub")
  }

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

data "azurerm_public_ip" "webapp_ip" {
  name                = azurerm_public_ip.webapp_public_ip.name
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [azurerm_public_ip.webapp_public_ip]
}

# Provisioner block: copies and runs Ansible

resource "null_resource" "provision_app" {
  depends_on = [azurerm_linux_virtual_machine.webapp_vm, azurerm_public_ip.webapp_public_ip]

  connection {
    type     = "ssh"
    user     = var.admin_username
    private_key = file("~/.ssh/terraform_key")
    host     = data.azurerm_public_ip.webapp_ip.ip_address
    timeout  = "2m"
  }

  provisioner "file" {
    source      = "ansible"
    destination = "/home/${var.admin_username}/ansible"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install ansible sshpass -y",
      "cd /home/${var.admin_username}/ansible",
      "chmod 600 spawn.sh",
      "chmod +x spawn.sh",
      "./spawn.sh",
      "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yml"
    ]
  }

  triggers = {
    always_run = timestamp()
  }
}

# Network security group with different priorities
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
