locals {
  subnet_names_prefixes_map = zipmap(var.subnet_names, var.subnet_prefixes)
  
  # Resolve vnet_name: use name if provided, otherwise use vnet_name
  resolved_vnet_name = var.name != null ? var.name : var.vnet_name
  
  # VPN Gateway name
  vpn_gateway_name = var.vpn_gateway_name != null ? var.vpn_gateway_name : "${local.resolved_vnet_name}-vpn-gateway"
  
  # Local Network Gateway name
  remote_gateway_name = var.remote_gateway_name != null ? var.remote_gateway_name : "${local.resolved_vnet_name}-remote-gateway"
  
  # VPN Connection name
  vpn_connection_name = var.vpn_connection_name != null ? var.vpn_connection_name : "${local.resolved_vnet_name}-vpn-connection"
  
  # NSG source address prefixes
  nsg_source_address_prefixes = length(var.internal_nsg_source_address_prefix) > 0 ? var.internal_nsg_source_address_prefix : (length(var.address_spaces) > 0 ? var.address_spaces : [var.address_space])
}