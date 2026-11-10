locals {
  base_cidr_block = "10.${var.binome}.0.0/16"

  common_tags = {
    projet = "ds final"
    owner  = var.nom
    env    = var.env
  }

  web_vms = toset(["web-1", "web-2"])
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-nimbus-${var.nom}"
  location = var.region
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-nimbus-${var.nom}"
  address_space       = [local.base_cidr_block]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web-nimbus-${var.nom}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(local.base_cidr_block, 8, 1)]
}

resource "azurerm_subnet" "admin" {
  name                 = "snet-admin-nimbus-${var.nom}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(local.base_cidr_block, 8, 2)]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-nimbus-${var.nom}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

resource "azurerm_network_security_rule" "web_http_internet" {
  name                        = "allow-http-internet-nimbus-${var.nom}"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_network_security_rule" "web_http_probe" {
  name                        = "allow-lb-probe-nimbus-${var.nom}"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_network_security_rule" "web_ssh_from_admin" {
  name                        = "allow-ssh-admin-nimbus-${var.nom}"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = cidrsubnet(local.base_cidr_block, 8, 2)
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_network_security_rule" "web_deny_other_inbound" {
  name                        = "deny-other-inbound-nimbus-${var.nom}"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web.name
}

resource "azurerm_network_security_group" "admin" {
  name                = "nsg-admin-nimbus-${var.nom}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

resource "azurerm_network_security_rule" "admin_ssh_from_internet" {
  name                        = "allow-ssh-ip-nimbus-${var.nom}"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.ssh_allowed_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.admin.name
}

resource "azurerm_network_security_rule" "admin_deny_inbound" {
  name                        = "deny-inbound-nimbus-${var.nom}"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.admin.name
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "admin" {
  subnet_id                 = azurerm_subnet.admin.id
  network_security_group_id = azurerm_network_security_group.admin.id
}

resource "azurerm_network_interface" "web" {
  for_each            = local.web_vms
  name                = "nic-nimbus-${var.nom}-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig-${each.key}"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  for_each                        = local.web_vms
  name                            = "vm-nimbus-${var.nom}-${each.key}"
  computer_name                   = each.key
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.web[each.key].id]
  custom_data                     = base64encode(templatefile("${path.module}/cloud-init.yaml", { hostname = each.key }))
  tags                            = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "jumpbox" {
  name                = "pip-jumpbox-nimbus-${var.nom}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "nic-jumpbox-nimbus-${var.nom}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig-jumpbox"
    subnet_id                     = azurerm_subnet.admin.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
    primary                       = true
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                            = "vm-jumpbox-nimbus-${var.nom}"
  computer_name                   = "jumpbox"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.jumpbox.id]
  tags                            = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-nimbus-${var.nom}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_lb" "web" {
  name                = "lb-nimbus-${var.nom}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tags                = local.common_tags

  frontend_ip_configuration {
    name                 = "frontend-public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "backend-web-nimbus-${var.nom}"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  for_each                = local.web_vms
  network_interface_id    = azurerm_network_interface.web[each.key].id
  ip_configuration_name   = "ipconfig-${each.key}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}

resource "azurerm_lb_probe" "web" {
  name            = "probe-http-nimbus-${var.nom}"
  loadbalancer_id = azurerm_lb.web.id
  protocol        = "Http"
  port            = 80
  request_path    = "/sante"
}

resource "azurerm_lb_rule" "web_http" {
  name                           = "rule-http-nimbus-${var.nom}"
  loadbalancer_id                 = azurerm_lb.web.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  disable_outbound_snat          = true
  frontend_ip_configuration_name = "frontend-public"
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.web.id]
  probe_id                        = azurerm_lb_probe.web.id
}

resource "azurerm_lb_outbound_rule" "web" {
  name                    = "outbound-nimbus-${var.nom}"
  loadbalancer_id         = azurerm_lb.web.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id

  frontend_ip_configuration {
    name = "frontend-public"
  }
}

output "site_url" {
  description = "URL publique du site NimbusShop"
  value       = "http://${azurerm_public_ip.lb.ip_address}"
}

output "load_balancer_public_ip" {
  description = "Adresse IP publique du Load Balancer"
  value       = azurerm_public_ip.lb.ip_address
}

output "jumpbox_public_ip" {
  description = "Adresse IP publique de la jumpbox pour la connexion SSH"
  value       = azurerm_public_ip.jumpbox.ip_address
}
