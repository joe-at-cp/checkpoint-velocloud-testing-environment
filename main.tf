#####################################################################
# CloudGuard Connect - Azure Performance Testing Environment
#####################################################################


#Azure Provider
provider "azurerm" {
    features {}
    skip_provider_registration = true
}

#Deployment Variables
#----------------------------------------------------------------------------------

variable "server_side_region" {
  type = string
  default  = "eastus"
}

variable "client_side_region" {
  type = string
  default  = "eastus"
}

data "template_file" "vce-cloud-init" {
  template = "${file("vce-init.tpl")}"
  vars = {
    vco = ""
    activation_key = ""
  }
}

#Server Side Resources
#----------------------------------------------------------------------------------

#Resource Group
resource "azurerm_resource_group" "cgc_server_rg" {
  name     = "cloudguardconnect_testing_server_rg"
  location = var.server_side_region
}

#Network
resource "azurerm_virtual_network" "cgc_server_rg_network" {
  name                = "server_network"
  location            = azurerm_resource_group.cgc_server_rg.location
  resource_group_name = azurerm_resource_group.cgc_server_rg.name
  address_space       = ["10.0.0.0/16"]
}

#Subnet
resource "azurerm_subnet" "cgc_server_rg_subnet" {
  name                 = "server_subnet"
  resource_group_name  = azurerm_resource_group.cgc_server_rg.name
  virtual_network_name = azurerm_virtual_network.cgc_server_rg_network.name
  address_prefixes       = ["10.0.1.0/24"]
}

#Public Ip
resource "azurerm_public_ip" "cgc_server_vm_publicip" {
    name                 = "cgc_server_vm_publicip"
    location             = azurerm_resource_group.cgc_server_rg.location
    resource_group_name  = azurerm_resource_group.cgc_server_rg.name
    allocation_method    = "Dynamic"
}

#Virtual NIC
resource "azurerm_network_interface" "cgc_server_vm_nic" {
  name                = "cgc_server_vm_nic"
  location            = azurerm_resource_group.cgc_server_rg.location
  resource_group_name = azurerm_resource_group.cgc_server_rg.name

  ip_configuration {
    name                          = "server_vm_ip"
    subnet_id                     = azurerm_subnet.cgc_server_rg_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cgc_server_vm_publicip.id
  }
}

#Ubuntu Server
resource "azurerm_virtual_machine" "cgc_server_vm" {
  name                  = "Performance_Testing_Server"
  location              = azurerm_resource_group.cgc_server_rg.location
  resource_group_name   = azurerm_resource_group.cgc_server_rg.name
  network_interface_ids = [azurerm_network_interface.cgc_server_vm_nic.id]
  vm_size               = "Standard_D4s_v3"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
    os_profile {
        computer_name  = "performanceserver"
        admin_username = "ubuntu"
        admin_password = "1qaz!QAZ1qaz!QAZ"
        custom_data    = file("custom_data.txt")
    }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}


#Client Side Resources
#----------------------------------------------------------------------------------

#Resouce Group
resource "azurerm_resource_group" "cgc_client_rg" {
  name     = "cloudguardconnect_testing_client_rg"
  location = var.client_side_region
}

#Network
resource "azurerm_virtual_network" "cgc_client_rg_network" {
  name                = "client_network"
  resource_group_name = azurerm_resource_group.cgc_client_rg.name
  location            = azurerm_resource_group.cgc_client_rg.location
  address_space       = ["10.0.0.0/16"]
}

#Edge Subnet
resource "azurerm_subnet" "cgc_client_rg_edge_subnet" {
  name                 = "edge_subnet"
  resource_group_name  = azurerm_resource_group.cgc_client_rg.name
  virtual_network_name = azurerm_virtual_network.cgc_client_rg_network.name
  address_prefixes       = ["10.0.5.0/24"]
}

#User Subnet
resource "azurerm_subnet" "cgc_client_rg_user_subnet" {
  name                 = "user_subnet"
  resource_group_name  = azurerm_resource_group.cgc_client_rg.name
  virtual_network_name = azurerm_virtual_network.cgc_client_rg_network.name
  address_prefixes       = ["10.0.10.0/24"]
}

#data "azurerm_public_ip" "cgc_server_ip" {
#  name                = azurerm_public_ip.cgc_server_vm_publicip.name
#  resource_group_name = azurerm_resource_group.cgc_server_rg.name
#}


#Edge Routing Table
resource "azurerm_route_table" "cgc_client_edge_rt" {
  name                = "cgc_client_edge_rt"
  location            = var.client_side_region
  resource_group_name = azurerm_resource_group.cgc_client_rg.name

  route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

#User Routing Table
resource "azurerm_route_table" "cgc_client_user_rt" {
  name                = "cgc_client_user_rt"
  location            = var.client_side_region
  resource_group_name = azurerm_resource_group.cgc_client_rg.name

  #route {
  #  name                   = "Performance_Server_Via_VCE"
  #  address_prefix         =  "${data.azurerm_public_ip.cgc_server_ip.ip_address}/32"
  #  #address_prefix         = "13.91.86.104/32"
  #  next_hop_type          = "VirtualAppliance"
  #  next_hop_in_ip_address = "10.0.10.5"
  #}

  route {
    name                   = "To_Edge_Subnet_10"
    address_prefix         = "10.0.10.0/24"
    next_hop_type          = "VnetLocal"
  }

  route {
    name                   = "To_Edge_Subnet_5"
    address_prefix         = "10.0.5.0/24"
    next_hop_type          = "VnetLocal"
  }
 
  route {
    name                   = "Default_Route"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "Internet"
  }

  depends_on = [
    azurerm_public_ip.cgc_server_vm_publicip
  ]
}

#User Routing Table Association
resource "azurerm_subnet_route_table_association" "example" {
  subnet_id      = azurerm_subnet.cgc_client_rg_user_subnet.id
  route_table_id = azurerm_route_table.cgc_client_user_rt.id
}

#Edge Routing Table Association
resource "azurerm_subnet_route_table_association" "edge_rt" {
  subnet_id      = azurerm_subnet.cgc_client_rg_edge_subnet.id
  route_table_id = azurerm_route_table.cgc_client_edge_rt.id
}

#Client Public Ip
resource "azurerm_public_ip" "cgc_client_vm_publicip" {
    name                 = "cgc_client_vm_publicip"
    location             = azurerm_resource_group.cgc_client_rg.location
    resource_group_name  = azurerm_resource_group.cgc_client_rg.name
    allocation_method    = "Dynamic"
}

#Windows Client Public Ip
resource "azurerm_public_ip" "cgc_windows_client_pip" {
    name                  = "WindowsClientPublicIP"
    location              = azurerm_resource_group.cgc_client_rg.location
    resource_group_name   = azurerm_resource_group.cgc_client_rg.name
    allocation_method     = "Dynamic"
}

#VCE Public Ip GE1
resource "azurerm_public_ip" "cgc_vce1_vm_publicip" {
    name                 = "cgc_vce1_vm_publicip"
    location             = azurerm_resource_group.cgc_client_rg.location
    resource_group_name  = azurerm_resource_group.cgc_client_rg.name
    allocation_method    = "Dynamic"
}

#VCE Public Ip GE2
resource "azurerm_public_ip" "cgc_vce2_vm_publicip" {
    name                 = "cgc_vce2_vm_publicip"
    location             = azurerm_resource_group.cgc_client_rg.location
    resource_group_name  = azurerm_resource_group.cgc_client_rg.name
    allocation_method    = "Dynamic"
}

#Client Side NSG
resource "azurerm_network_security_group" "cgc_client_nsg" {
  name                = "cgc_client_nsg"
  location            = azurerm_resource_group.cgc_client_rg.location
  resource_group_name = azurerm_resource_group.cgc_client_rg.name

  security_rule {
    name                       = "any_inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "any_outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#Client Side NSG Association
resource "azurerm_network_interface_security_group_association" "client_nsg_associate_ge1" {
  network_interface_id      = azurerm_network_interface.cgc_vce_vm_nic_ge1.id
  network_security_group_id = azurerm_network_security_group.cgc_client_nsg.id
}

resource "azurerm_network_interface_security_group_association" "client_nsg_associate_ge2" {
  network_interface_id      = azurerm_network_interface.cgc_vce_vm_nic_ge2.id
  network_security_group_id = azurerm_network_security_group.cgc_client_nsg.id
}

resource "azurerm_network_interface_security_group_association" "client_nsg_associate_ge3" {
  network_interface_id      = azurerm_network_interface.cgc_vce_vm_nic_ge3.id
  network_security_group_id = azurerm_network_security_group.cgc_client_nsg.id
}

resource "azurerm_network_interface_security_group_association" "client_nsg_associate_client_nic" {
  network_interface_id      = azurerm_network_interface.cgc_client_vm_nic.id
  network_security_group_id = azurerm_network_security_group.cgc_client_nsg.id
}

resource "azurerm_network_interface_security_group_association" "client_nsg_associate_windows_client_nic" {
  network_interface_id      = azurerm_network_interface.cgc_windows_client_nic.id
  network_security_group_id = azurerm_network_security_group.cgc_client_nsg.id
}


#VCE GE1 Virtual NIC
resource "azurerm_network_interface" "cgc_vce_vm_nic_ge1" {
  name                = "cgc_vce_vm_nic_ge1"
  location            = azurerm_resource_group.cgc_client_rg.location
  resource_group_name = azurerm_resource_group.cgc_client_rg.name

  ip_configuration {
    name                          = "vce_vm_ge1_ip"
    subnet_id                     = azurerm_subnet.cgc_client_rg_edge_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.5.4"
    public_ip_address_id          = azurerm_public_ip.cgc_vce1_vm_publicip.id
  }
}

#VCE GE2 Virtual NIC
resource "azurerm_network_interface" "cgc_vce_vm_nic_ge2" {
  name                = "cgc_vce_vm_nic_ge2"
  location            = azurerm_resource_group.cgc_client_rg.location
  resource_group_name = azurerm_resource_group.cgc_client_rg.name

  ip_configuration {
    name                          = "vce_vm_ge2_ip"
    subnet_id                     = azurerm_subnet.cgc_client_rg_edge_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.5.5"
    public_ip_address_id          = azurerm_public_ip.cgc_vce2_vm_publicip.id
  }
}

#VCE GE3 Virtual NIC
resource "azurerm_network_interface" "cgc_vce_vm_nic_ge3" {
  name                = "cgc_vce_vm_nic_ge3"
  location            = azurerm_resource_group.cgc_client_rg.location
  resource_group_name = azurerm_resource_group.cgc_client_rg.name

  ip_configuration {
    name                          = "vce_vm_ge3_ip"
    subnet_id                     = azurerm_subnet.cgc_client_rg_user_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.10.5"
  }
}

#Client Virtual NIC
resource "azurerm_network_interface" "cgc_client_vm_nic" {
  name                = "cgc_client_vm_nic"
  location            = azurerm_resource_group.cgc_client_rg.location
  resource_group_name = azurerm_resource_group.cgc_client_rg.name

  ip_configuration {
    name                          = "server_vm_ip"
    subnet_id                     = azurerm_subnet.cgc_client_rg_user_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.10.10"
    public_ip_address_id          = azurerm_public_ip.cgc_client_vm_publicip.id
  }
}

#Client Ubuntu Server
resource "azurerm_virtual_machine" "cgc_client_vm" {
  name                  = "Performance_Testing_Client"
  location              = azurerm_resource_group.cgc_client_rg.location
  resource_group_name   = azurerm_resource_group.cgc_client_rg.name
  network_interface_ids = [azurerm_network_interface.cgc_client_vm_nic.id]
  vm_size               = "Standard_D4s_v3"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "client_osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
    os_profile {
        computer_name  = "performanceclient"
        admin_username = "ubuntu"
        admin_password = "1qaz!QAZ1qaz!QAZ"
        custom_data    = file("custom_data.txt")
    }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

#Windows Host Nic
resource "azurerm_network_interface" "cgc_windows_client_nic" {
    name                = "myNIC"
    location              = azurerm_resource_group.cgc_client_rg.location
    resource_group_name   = azurerm_resource_group.cgc_client_rg.name

    ip_configuration {
      name                          = "WindowsclientNicConfiguration"
      subnet_id                     = azurerm_subnet.cgc_client_rg_user_subnet.id
      private_ip_address_allocation = "Static"
      private_ip_address            = "10.0.10.20"
      public_ip_address_id          = azurerm_public_ip.cgc_windows_client_pip.id
    }
}

#Windows Client
resource "azurerm_virtual_machine" "cgc_windows_client_vm" {
  name                  = "WindowsClient"
  location              = azurerm_resource_group.cgc_client_rg.location
  resource_group_name   = azurerm_resource_group.cgc_client_rg.name
  vm_size               = "Standard_B2ms"
  network_interface_ids = ["${azurerm_network_interface.cgc_windows_client_nic.id}"]

  storage_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "rs5-pro"
    version   = "latest"
  }

  storage_os_disk {
    name          = "windowsclient-osdisk1"
    caching       = "ReadWrite"
    create_option = "FromImage"
    os_type       = "windows"
  }

  os_profile {
    computer_name  = "WindowsClient"
    admin_username = "client"
    admin_password = "1qaz!QAZ1qaz!QAZ"
  }

  os_profile_windows_config {
  }
}


#VeloCloud VCE
resource "azurerm_linux_virtual_machine" "cgc_vce_vm" {
  name                  = "VeloCloud_VCE"
  location              = azurerm_resource_group.cgc_client_rg.location
  resource_group_name   = azurerm_resource_group.cgc_client_rg.name
  network_interface_ids = ["${azurerm_network_interface.cgc_vce_vm_nic_ge1.id}","${azurerm_network_interface.cgc_vce_vm_nic_ge2.id}","${azurerm_network_interface.cgc_vce_vm_nic_ge3.id}"]
  size                  = "Standard_DS3_v2"

  computer_name                     = "vce"
  admin_username                    = "vcadmin"
  admin_password                    = "Velocloud123!"
  disable_password_authentication   = false
  custom_data = base64encode(data.template_file.vce-cloud-init.rendered)

  os_disk {
      name                  = "vce-os-disk"
      caching               = "ReadWrite"
      storage_account_type = "Premium_LRS"
  }

  plan {
    name = "velocloud-virtual-edge-3x"
    publisher = "velocloud"
    product = "velocloud-virtual-edge-3x"
  }

  source_image_reference {
    publisher = "velocloud"
    offer     = "velocloud-virtual-edge-3x"
    sku       = "velocloud-virtual-edge-3x"
    version   = "3.3.2"
  }
}
