resource "azurerm_resource_group" "main_vpc" {
  name     = "kml_rg_main-0f193cc741c04362"
  location = "westus" # or whatever region the RG is in
}


resource "azurerm_virtual_network" "my_vpc" {
    count               = 2
    name                = "my_vpc-${count.index + 1}"
    address_space       = ["10.0.${count.index}.0/16"]
    location            = azurerm_resource_group.main_vpc.location
    resource_group_name = azurerm_resource_group.main_vpc.name

    tags = {
        environment = "production"
    }
}

resource "azurerm_subnet" "my_azure_subnet" {
    count                = 2
    name                 = "my_azure_subnet-${count.index + 1}"
    resource_group_name  = azurerm_resource_group.main_vpc.name
    virtual_network_name = azurerm_virtual_network.my_vpc[count.index].name
    address_prefixes     = ["10.0.${count.index}.0/24"]
    service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_network_security_group" "my_azure_igw" {
    count               = 2
    name                = "my_azure_igw-${count.index + 1}"
    location            = azurerm_resource_group.main_vpc.location
    resource_group_name = azurerm_resource_group.main_vpc.name

    security_rule {
        name                       = "AllowSSH"
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["22"]
        source_address_prefixes    = ["*"]
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "AllowHTTP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["80"]
        source_address_prefixes    = ["*"]
        destination_address_prefix = "*"
    }
}

resource "azurerm_subnet_network_security_group_association" "my_azure_subnet_nsg_association" {
    count                     = 2
    subnet_id                 = azurerm_subnet.my_azure_subnet[count.index].id
    network_security_group_id = azurerm_network_security_group.my_azure_igw[count.index].id
    depends_on                = [azurerm_subnet.my_azure_subnet]
    lifecycle {
        ignore_changes = [network_security_group_id]
    }
}

resource "azurerm_public_ip" "my_public_ip" {
    count               = 2
    name                = "my_public_ip-${count.index + 1}"
    location            = azurerm_resource_group.main_vpc.location
    resource_group_name = azurerm_resource_group.main_vpc.name
    allocation_method   = "Static"

    tags = {
        environment = "production"
    }
}

resource "azurerm_network_interface" "my_network_interface" {
    count               = 2
    name                = "my_network_interface-${count.index + 1}"
    location            = azurerm_resource_group.main_vpc.location
    resource_group_name = azurerm_resource_group.main_vpc.name

    ip_configuration {
        name                          = "my_ip_configuration-${count.index + 1}"
        subnet_id                     = azurerm_subnet.my_azure_subnet[count.index].id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.my_public_ip[count.index].id
    }

    tags = {
        environment = "production"
    }
}


resource "azurerm_linux_virtual_machine" "my_linux_vm" {
    count               = 2
    name                = "my_linux_vm-${count.index + 1}"
    resource_group_name = azurerm_resource_group.main_vpc.name
    location            = azurerm_resource_group.main_vpc.location
    size                = "Standard_DS1_v2"
    admin_username      = "adminuser"
    admin_password      = "Passw0rd1234!" # Use a secure password in production

    network_interface_ids = [
        azurerm_network_interface.my_network_interface[count.index].id,
    ]

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

    tags = {
        environment = "production"
    }
}