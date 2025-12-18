output "default_nat_gateway_name" {
  description = "Expected: test-vnet-xxx-nat-gateway"
  value       = module.network_default.nat_gateway_id != null ? "NAT Gateway created" : "NAT Gateway not created"
}

output "default_nat_gateway_public_ip" {
  description = "Expected: test-vnet-xxx-nat-gateway-pip"
  value       = module.network_default.nat_gateway_public_ip_address
}

output "default_nsg_name" {
  description = "Expected: test-vnet-xxx-internal (with VNet prefix)"
  value       = module.network_default.network_security_group_id != null ? "NSG created" : "NSG not created"
}

output "explicit_nat_gateway_name" {
  description = "Expected: custom-nat-gateway"
  value       = module.network_explicit.nat_gateway_id != null ? "NAT Gateway created" : "NAT Gateway not created"
}

output "explicit_nsg_name" {
  description = "Expected: internal (without VNet prefix, backward compatible)"
  value       = module.network_explicit.network_security_group_id != null ? "NSG created" : "NSG not created"
}

