provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "West Europe"
}

resource "random_id" "rg_name" {
  byte_length = 8
}

resource "azurerm_resource_group" "test" {
  location = var.location
  name     = "test-naming-rg-${random_id.rg_name.hex}"
}

# Test with default naming (nat_gateway_name = null)
module "network_default" {
  source = "../../"

  name                = "test-vnet-${random_id.rg_name.hex}"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  address_spaces      = ["10.0.0.0/16"]
  subnet_names        = ["subnet1", "subnet2"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24"]
  use_for_each        = true

  # NAT Gateway with default naming
  enable_nat_gateway                  = true
  nat_gateway_subnet_names            = ["subnet1", "subnet2"]
  nat_gateway_idle_timeout_in_minutes = 4
  # nat_gateway_name = null (default) - should create "test-vnet-xxx-nat-gateway"

  # NSG with VNet prefix (default)
  enable_internal_nsg                = true
  internal_nsg_name                  = "internal"
  # internal_nsg_use_vnet_prefix = true (default) - should create "test-vnet-xxx-internal"
  attach_nsg_to_subnets              = ["subnet1"]
  internal_nsg_source_address_prefix  = ["10.0.0.0/16"]

  tags = {
    Environment = "test"
    Purpose     = "naming-test"
  }

  depends_on = [azurerm_resource_group.test]
}

# Test with explicit naming
module "network_explicit" {
  source = "../../"

  name                = "test-vnet-explicit-${random_id.rg_name.hex}"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  address_spaces      = ["10.1.0.0/16"]
  subnet_names        = ["subnet1"]
  subnet_prefixes     = ["10.1.1.0/24"]
  use_for_each        = true

  # NAT Gateway with explicit naming
  enable_nat_gateway                  = true
  nat_gateway_subnet_names            = ["subnet1"]
  nat_gateway_name                    = "custom-nat-gateway"
  # Should create "custom-nat-gateway" and "custom-nat-gateway-pip"

  # NSG without VNet prefix (backward compatible)
  enable_internal_nsg                = true
  internal_nsg_name                  = "internal"
  internal_nsg_use_vnet_prefix      = false
  # Should create "internal" (not "test-vnet-explicit-xxx-internal")
  attach_nsg_to_subnets              = ["subnet1"]
  internal_nsg_source_address_prefix = ["10.1.0.0/16"]

  tags = {
    Environment = "test"
    Purpose     = "naming-test-explicit"
  }

  depends_on = [azurerm_resource_group.test]
}

