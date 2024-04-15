# Define Azure provider
provider "azurerm" {
  features {}
}

# Define AppGateway resource group
resource "azurerm_resource_group" "dmz" {
  name     = "dmz"
  location = "East US"
}

# Define Governor(frontend) resource group
resource "azurerm_resource_group" "Governor" {
  name     = "Governor"
  location = "East US"
}

# Define Jadis(backend) resource group
resource "azurerm_resource_group" "Jadis" {
  name     = "Jadis"
  location = "East US"
}

# Define Negan(database) resource group
resource "azurerm_resource_group" "Negan" {
  name     = "Negan"
  location = "East US"
}


# Define public IP address for Application Gateway
resource "azurerm_public_ip" "dmz_publicip" {
  name                = "dmz_publicip"
  resource_group_name = azurerm_resource_group.dmz.name
  location            = azurerm_resource_group.dmz.location
  allocation_method   = "Static"
}

# Define Application Gateway
resource "azurerm_application_gateway" "dmz_appgateway" {
  name                = "dmz_appgateway"
  resource_group_name = azurerm_resource_group.dmz.name
  location            = azurerm_resource_group.dmz.location
  sku {
    name     = "Standard_v2"
    tier     = "WAF V2"
    capacity = 2
  }
  gateway_ip_configuration {
    name      = "dmzIpConfiguration"
    subnet_id = azurerm_subnet.dmz_subnet.id
  }
  ssl_certificate {
    name            = "dev_my_rcm_app-cert"
    data            = filebase64("dev_my_rcm_app.pem")
   
  }
  frontend_port {
    name = "port443"
    port = 443
  }
  frontend_ip_configuration {
    name                 = "dmzFrontendIP"
    public_ip_address_id = azurerm_public_ip.dmz_publicip.id
  }
  http_settings {
    name                      = "dmzHttpsSettings"
    cookie_based_affinity     = "Disabled"
    port                      = 443
    protocol                  = "Https"
    request_timeout_seconds   = 20
    ssl_certificate_name      = "dev_my_rcm_app-cert"
  }
  http_listener {
    name                           = "dmzHttpsListener"
    frontend_ip_configuration_name = "dmzFrontendIP"
    frontend_port_name             = "port443"
    protocol                       = "Https"
    ssl_certificate_name           = "dev_my_rcm_app-cert"
  }
  backend_address_pool {
    name = "Governor_pool"
    backend_addresses = [
      azurerm_virtual_machine.Governor.private_ip_address
    ]
  }
}

# Define AppGateway(dmz) subnet 
resource "azurerm_subnet" "dmz_subnet" {
  name                 = "dmz_subnet"
  resource_group_name  = azurerm_resource_group.dmz.name
  virtual_network_name = azurerm_virtual_network.Myrcmapp_vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

# Define Governor(frontend) subnet 
resource "azurerm_subnet" "Governor_subnet" {
  name                 = "Governor_subnet"
  resource_group_name  = azurerm_resource_group.Governor.name
  virtual_network_name = azurerm_virtual_network.Governor.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Define myrcmapp virtual network
resource "azurerm_virtual_network" "Myrcmapp" {
  name                = "Myrcmapp-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.Negan.location
  resource_group_name = azurerm_resource_group.Negan.name
}

# Define frontend Linux VM
resource "azurerm_linux_virtual_machine" "Governor_vm" {
  name                = "Governor_vm"
  location            = azurerm_resource_group.Governor.location
  resource_group_name = azurerm_resource_group.Governor.name
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.Governor_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# Define Governor (frontend) network interface
resource "azurerm_network_interface" "Governor_nic" {
  name                = "Governor_nic"
  location            = azurerm_resource_group.Governor.location
  resource_group_name = azurerm_resource_group.Governor.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Governor_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Define network security group (NSG) for Governor (frontend) VM
resource "azurerm_network_security_group" "Governor_nsg" {
  name                = "Governor_nsg"
  location            = azurerm_resource_group.Governor.location
  resource_group_name = azurerm_resource_group.Governor.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Define Jadis(backend) subnet 
resource "azurerm_subnet" "Jadis_subnet" {
  name                 = "Jadis_subnet"
  resource_group_name  = azurerm_resource_group.Jadis.name
  virtual_network_name = azurerm_virtual_network.Myrcmapp_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


# Define backend Linux VM
resource "azurerm_linux_virtual_machine" "Jadis_vm" {
  name                = "Jadis_vm"
  location            = azurerm_resource_group.Jadis.location
  resource_group_name = azurerm_resource_group.Jadis.name
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.Jadis_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# Define network interface
resource "azurerm_network_interface" "Jadis_nic" {
  name                = "Jadis_nic"
  location            = azurerm_resource_group.Jadis.location
  resource_group_name = azurerm_resource_group.Jadis.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Jadis_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Define network security group (NSG) for Jadis (backend) VM
resource "azurerm_network_security_group" "Jadis_nsg" {
  name                = "Jadis_nsg"
  location            = azurerm_resource_group.Jadis.location
  resource_group_name = azurerm_resource_group.Jadis.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowDatabase"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Define Negan(database) subnet 
resource "azurerm_subnet" "Negan_subnet" {
  name                 = "Negan_subnet"
  resource_group_name  = azurerm_resource_group.Negan.name
  virtual_network_name = azurerm_virtual_network.Myrcmapp_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Define Negan database Windows VM
resource "azurerm_windows_virtual_machine" "Negan_vm" {
  name                = "Negan_vm"
  location            = azurerm_resource_group.Negan.location
  resource_group_name = azurerm_resource_group.Negan.name
  size                = "Standard_D2s v3"
  admin_username      = "azureuser"
  admin_password      = "Password123!"  # Replace with your desired password
  network_interface_ids = [azurerm_network_interface.Negan_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# Define Negan(database) network interfaces

resource "azurerm_network_interface" "Negan_nic" {
  name                = "Negan_nic"
  location            = azurerm_resource_group.Negan.location
  resource_group_name = azurerm_resource_group.Negan.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }

  network_security_group_id = azurerm_network_security_group.database_nsg.id
}

# Define network security group (NSG) for database VM
resource "azurerm_network_security_group" "Negan_nsg" {
  name                = "Negan_nsg"
  location            = azurerm_resource_group.Negan.location
  resource_group_name = azurerm_resource_group.Negan.name

  security_rule {
    name                       = "AllowDatabase"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}