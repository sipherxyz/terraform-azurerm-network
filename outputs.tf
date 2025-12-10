output "vnet_address_space" {
  description = "The address space of the newly created vNet"
  value       = azurerm_virtual_network.vnet.address_space
}

output "vnet_id" {
  description = "The id of the newly created vNet"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_location" {
  description = "The location of the newly created vNet"
  value       = azurerm_virtual_network.vnet.location
}

output "vnet_name" {
  description = "The name of the newly created vNet"
  value       = azurerm_virtual_network.vnet.name
}

output "vnet_subnets" {
  description = "The ids of subnets created inside the newly created vNet"
  value       = local.azurerm_subnets[*].id
}

output "subnet_ids" {
  description = "Map of subnet IDs, keyed by subnet name. Use this to get individual subnet IDs without needing a data source."
  value = var.use_for_each ? {
    for k, v in azurerm_subnet.subnet_for_each : k => v.id
  } : {
    for i, name in var.subnet_names : name => azurerm_subnet.subnet_count[i].id
  }
}

output "gateway_subnet_id" {
  description = "The id of the gateway subnet (if VPN Gateway is enabled)"
  value       = var.enable_vpn_gateway && var.gateway_subnet_cidr != null ? azurerm_subnet.gateway[0].id : null
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (single instance shared by all subnets)"
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip_address" {
  description = "Public IP address of the NAT Gateway"
  value       = var.enable_nat_gateway ? azurerm_public_ip.nat[0].ip_address : null
}

output "vpn_gateway_id" {
  description = "The id of the VPN Gateway (if enabled)"
  value       = var.enable_vpn_gateway ? azurerm_virtual_network_gateway.main[0].id : null
}

output "vpn_gateway_public_ip_address" {
  description = "The public IP address of the VPN Gateway (if enabled)"
  value       = var.enable_vpn_gateway ? azurerm_public_ip.vpn_gateway[0].ip_address : null
}

output "local_network_gateway_id" {
  description = "The id of the Local Network Gateway (if VPN Gateway is enabled)"
  value       = var.enable_vpn_gateway && var.remote_gateway_ip != null ? azurerm_local_network_gateway.main[0].id : null
}

output "vpn_connection_id" {
  description = "The id of the VPN Connection (if enabled)"
  value       = var.enable_vpn_gateway && var.remote_gateway_ip != null && var.vpn_shared_key != null ? azurerm_virtual_network_gateway_connection.main[0].id : null
}

output "network_security_group_id" {
  description = "The id of the internal Network Security Group (if enabled)"
  value       = var.enable_internal_nsg ? azurerm_network_security_group.internal[0].id : null
}
