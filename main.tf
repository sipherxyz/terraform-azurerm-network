#Azure Generic vNet Module
data "azurerm_resource_group" "network" {
  count = var.resource_group_location == null && var.location == null ? 1 : 0

  name = var.resource_group_name
}

locals {
  # Resolve location: use location if provided, otherwise use resource_group_location, otherwise get from resource group
  resolved_location = coalesce(
    var.location,
    var.resource_group_location,
    try(data.azurerm_resource_group.network[0].location, null)
  )
  resource_group_location = coalesce(
    var.resource_group_location,
    var.location,
    try(data.azurerm_resource_group.network[0].location, null)
  )
}

resource "azurerm_virtual_network" "vnet" {
  address_space       = length(var.address_spaces) == 0 ? [var.address_space] : var.address_spaces
  location            = local.resolved_location
  name                = local.resolved_vnet_name
  resource_group_name = var.resource_group_name
  dns_servers         = var.dns_servers
  tags = merge(var.tags, (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_git_commit           = "c506f86f75a34ad34c2b4437e8076f1f06bf6a00"
    avm_git_file             = "main.tf"
    avm_git_last_modified_at = "2022-11-23 09:20:55"
    avm_git_org              = "Azure"
    avm_git_repo             = "terraform-azurerm-network"
    avm_yor_trace            = "7f614813-224a-46c0-91d7-855dc7d6d5db"
    } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/), (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_yor_name = "vnet"
  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/))
}

moved {
  from = azurerm_subnet.subnet
  to   = azurerm_subnet.subnet_count
}

resource "azurerm_subnet" "subnet_count" {
  count = var.use_for_each ? 0 : length(var.subnet_names)

  address_prefixes = [var.subnet_prefixes[count.index]]
  name             = var.subnet_names[count.index]
  resource_group_name = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  # Note: private_endpoint_network_policies_enabled may not be available in all azurerm versions
  # If needed, this can be configured via Azure Portal or CLI
  service_endpoints = lookup(var.subnet_service_endpoints, var.subnet_names[count.index], [])

  dynamic "delegation" {
    for_each = lookup(var.subnet_delegation, var.subnet_names[count.index], [])

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

resource "azurerm_subnet" "subnet_for_each" {
  for_each = var.use_for_each ? toset(var.subnet_names) : []

  address_prefixes = [local.subnet_names_prefixes_map[each.value]]
  name             = each.value
  resource_group_name = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  # Note: private_endpoint_network_policies_enabled may not be available in all azurerm versions
  # If needed, this can be configured via Azure Portal or CLI
  service_endpoints = lookup(var.subnet_service_endpoints, each.value, [])

  dynamic "delegation" {
    for_each = lookup(var.subnet_delegation, each.value, [])

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

locals {
  azurerm_subnets = var.use_for_each ? [for s in azurerm_subnet.subnet_for_each : s] : [for s in azurerm_subnet.subnet_count : s]
}

# Gateway Subnet for VPN Gateway
resource "azurerm_subnet" "gateway" {
  count = var.enable_vpn_gateway && var.gateway_subnet_cidr != null ? 1 : 0

  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# NAT Gateway Public IPs
resource "azurerm_public_ip" "nat" {
  for_each = var.enable_nat_gateway ? toset(var.nat_gateway_subnet_names) : []

  name                = "${local.resolved_vnet_name}-nat-${each.value}-pip"
  location            = local.resolved_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# NAT Gateways
resource "azurerm_nat_gateway" "main" {
  for_each = var.enable_nat_gateway ? toset(var.nat_gateway_subnet_names) : []

  name                    = local.nat_gateway_names[each.value]
  location                = local.resolved_location
  resource_group_name     = var.resource_group_name
  idle_timeout_in_minutes = var.nat_gateway_idle_timeout_in_minutes
  sku_name                = "Standard"
  zones                   = ["1", "2", "3"]
  tags                    = var.tags
}

# Associate NAT Gateway Public IPs
resource "azurerm_nat_gateway_public_ip_association" "main" {
  for_each = var.enable_nat_gateway ? toset(var.nat_gateway_subnet_names) : []

  nat_gateway_id       = azurerm_nat_gateway.main[each.value].id
  public_ip_address_id = azurerm_public_ip.nat[each.value].id
}

# Associate NAT Gateways to Subnets
resource "azurerm_subnet_nat_gateway_association" "main" {
  for_each = var.enable_nat_gateway ? {
    for subnet_name in var.nat_gateway_subnet_names :
    subnet_name => subnet_name
    if contains(var.subnet_names, subnet_name)
  } : {}

  subnet_id      = local.subnet_map[each.value].id
  nat_gateway_id = azurerm_nat_gateway.main[each.value].id
}

# VPN Gateway Public IP
resource "azurerm_public_ip" "vpn_gateway" {
  count = var.enable_vpn_gateway ? 1 : 0

  name                = "${local.vpn_gateway_name}-pip"
  location            = local.resolved_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "main" {
  count = var.enable_vpn_gateway ? 1 : 0

  name                = local.vpn_gateway_name
  location            = local.resolved_location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = var.vpn_gateway_enable_bgp
  sku           = var.vpn_gateway_sku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway[0].id
  }

  tags = var.tags

  depends_on = [azurerm_subnet.gateway]
}

# Local Network Gateway (Remote Gateway)
resource "azurerm_local_network_gateway" "main" {
  count = var.enable_vpn_gateway && var.remote_gateway_ip != null ? 1 : 0

  name                = local.remote_gateway_name
  location            = local.resolved_location
  resource_group_name = var.resource_group_name
  gateway_address     = var.remote_gateway_ip
  address_space       = var.remote_address_spaces

  tags = var.tags
}

# VPN Connection
resource "azurerm_virtual_network_gateway_connection" "main" {
  count = var.enable_vpn_gateway && var.remote_gateway_ip != null && var.vpn_shared_key != null ? 1 : 0

  name                = local.vpn_connection_name
  location            = local.resolved_location
  resource_group_name = var.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.main[0].id

  shared_key = var.vpn_shared_key

  tags = var.tags
}

# Network Security Group
resource "azurerm_network_security_group" "internal" {
  count = var.enable_internal_nsg ? 1 : 0

  name                = var.internal_nsg_name
  location            = local.resolved_location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# NSG Rules - Allow internal traffic
resource "azurerm_network_security_rule" "allow_internal_inbound" {
  for_each = var.enable_internal_nsg ? {
    for prefix in local.nsg_source_address_prefixes :
    replace(prefix, "/", "-") => prefix
  } : {}

  name                        = "Allow-Internal-Inbound-${replace(each.value, "/", "-")}"
  priority                    = 1000 + index(local.nsg_source_address_prefixes, each.value)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = each.value
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.internal[0].name
}

# NSG Rules - Allow internal outbound
resource "azurerm_network_security_rule" "allow_internal_outbound" {
  for_each = var.enable_internal_nsg ? {
    for prefix in local.nsg_source_address_prefixes :
    replace(prefix, "/", "-") => prefix
  } : {}

  name                        = "Allow-Internal-Outbound-${replace(each.value, "/", "-")}"
  priority                    = 2000 + index(local.nsg_source_address_prefixes, each.value)
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = each.value
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.internal[0].name
}

# Associate NSG to all subnets
resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = var.enable_internal_nsg ? local.subnet_map : {}

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.internal[0].id
}