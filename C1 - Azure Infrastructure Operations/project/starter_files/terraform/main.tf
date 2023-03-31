
# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}


# Create a resource group
resource "azurerm_resource_group" "terraform_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "terraform_network" {
  name                = "myNetwork"
  resource_group_name = azurerm_resource_group.terraform_rg.name
  location            = azurerm_resource_group.terraform_rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet within the resource group
resource "azurerm_subnet" "terraform_subnet" {
  name                = "mySubnet"
  resource_group_name = azurerm_resource_group.terraform_rg.name
  virtual_network_name = azurerm_virtual_network.terraform_network.name
  address_prefixes = ["10.0.0.0/24"] 
}

# Create a Network sercurity group within the resource group
resource "azurerm_network_security_group" "terraform_network_security_group" {
  name                = "myNSG"
  resource_group_name = azurerm_resource_group.terraform_rg.name
  location            = azurerm_resource_group.terraform_rg.location

  security_rule {
    name = "allow-from-subnet"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "*"
    source_address_prefix = "VirtualNetwork"
    source_port_range = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_range = "*"
  }

  security_rule {
    name = "deny-internet"
    priority = 200
    direction = "Inbound"
    access = "Deny"
    protocol = "*"
    source_address_prefix = "Internet"
    source_port_range = "*"
    destination_address_prefix = "*"
    destination_port_range = "*"
  }
}

# Create a network interface within the resource group
resource "azurerm_network_interface" "terraform_network_interface" {
  count               = var.vm_count
  name                = "myNetworkInterface-${count.index}"
  resource_group_name = azurerm_resource_group.terraform_rg.name
  location            = azurerm_resource_group.terraform_rg.location
  
  ip_configuration {
    primary                       = true
    name                          = "internal"
    subnet_id                     = azurerm_subnet.terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "terraform_security_group_association" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.terraform_network_interface[count.index].id
  network_security_group_id = azurerm_network_security_group.terraform_network_security_group.id
}

# Create a pubic IP within the resource group
resource "azurerm_public_ip" "terraform_public_ip" {
  name                = "myPublicIP"
  resource_group_name = azurerm_resource_group.terraform_rg.name
  location            = azurerm_resource_group.terraform_rg.location
  allocation_method   = "Dynamic"
}

# Create load balancer
resource "azurerm_lb" "terraform_load_balancer" {
  name                = "myLoadBalancer"
  resource_group_name = azurerm_resource_group.terraform_rg.name
  location            = azurerm_resource_group.terraform_rg.location

  frontend_ip_configuration {
    name                 = "myLoadBalancer_FE"
    public_ip_address_id = azurerm_public_ip.terraform_public_ip.id
  }
}

# Create a new backend configuration 
resource "azurerm_lb_backend_address_pool" "terraform_backend_pool"{
  loadbalancer_id = azurerm_lb.terraform_load_balancer.id
  name = "myLoadBalancer_BE"
}

# Associate load balancer with the backend address pool
resource "azurerm_network_interface_backend_address_pool_association" "terraform_backend_pool_association" {
  count = var.vm_count

  network_interface_id    = azurerm_network_interface.terraform_network_interface[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.terraform_backend_pool.id
}

# Create virtual machine availability set
resource "azurerm_availability_set" "terraform_availability_set" {
  name                = "myAvailabilitySet"
  location            = azurerm_resource_group.terraform_rg.location
  resource_group_name = azurerm_resource_group.terraform_rg.name
}

# Create packer image
data "azurerm_image" "packer_vm"{
  name = "UbuntuServer"
  resource_group_name = azurerm_resource_group.terraform_rg.name
}

# Create VM from image
resource "azurerm_virtual_machine" "terraform_vm" {
  count = var.vm_count
  name                  = "myVM-${count.index}"
  location              = azurerm_resource_group.terraform_rg.location
  resource_group_name   = azurerm_resource_group.terraform_rg.name
  network_interface_ids = [element(azurerm_network_interface.terraform_network_interface.*.id, count.index)]
  vm_size               = "Standard_B1s"
  availability_set_id   = azurerm_availability_set.terraform_availability_set.id


  storage_image_reference {
    id = "${data.azurerm_image.packer_vm.id}"
  }

  storage_os_disk {
    name = "myDiskOs-${count.index}"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile{
  computer_name = "TungVM-${count.index}"
  admin_username = var.username
  admin_password = var.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# Create disk management for each VM

resource "azurerm_managed_disk" "terraform_disk_management" {
  count               = var.vm_count
  name                = "vm-disk-${count.index}"
  location            = azurerm_resource_group.terraform_rg.location
  resource_group_name = azurerm_resource_group.terraform_rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 1
}

resource "azurerm_virtual_machine_data_disk_attachment" "terraform_vm_data_disk_attachment" {
  count            = var.vm_count
  managed_disk_id  = azurerm_managed_disk.terraform_disk_management[count.index].id
  virtual_machine_id = azurerm_virtual_machine.terraform_vm[count.index].id
  lun              = 10 * count.index
  caching          = "ReadWrite"
  create_option    = "Attach"
}

