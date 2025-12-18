# Prompt for Updating terraform-azurerm-network Module

## Context
I need to update the GitHub module `github.com/sipherxyz/terraform-azurerm-network` to improve naming conventions and maintain backward compatibility with existing Azure resources.

## Current Issues

### 1. NAT Gateway Public IP Naming
**Current behavior:**
- If `nat_gateway_name` is provided: Public IP is named `${var.nat_gateway_name}-pip`
- If `nat_gateway_name` is null: Public IP is named `${local.resolved_vnet_name}-nat-pip`

**Problem:**
- Existing deployments use the pattern `${vnet_name}-nat-gateway-pip` (e.g., "g1-nat-gateway-pip")
- When `nat_gateway_name = "g1-nat-gateway"` is set, the Public IP becomes "g1-nat-gateway-pip" which is correct
- However, when `nat_gateway_name` is null, it creates "g1-nat-pip" instead of "g1-nat-gateway-pip"

**Desired behavior:**
- When `nat_gateway_name` is null, the Public IP should be named `${local.resolved_vnet_name}-nat-gateway-pip` (not `${local.resolved_vnet_name}-nat-pip`)
- This maintains consistency with existing deployments and the pattern used when `nat_gateway_name` is explicitly set

### 2. NAT Gateway Naming
**Current behavior:**
- If `nat_gateway_name` is provided: NAT Gateway uses that name
- If `nat_gateway_name` is null: NAT Gateway is named `${local.resolved_vnet_name}-nat`

**Problem:**
- Existing deployments use `${vnet_name}-nat-gateway` pattern (e.g., "g1-nat-gateway")
- When `nat_gateway_name` is null, it creates "g1-nat" instead of "g1-nat-gateway"

**Desired behavior:**
- When `nat_gateway_name` is null, the NAT Gateway should be named `${local.resolved_vnet_name}-nat-gateway` (not `${local.resolved_vnet_name}-nat`)

### 3. Internal NSG Naming
**Current behavior:**
- NSG name uses `var.internal_nsg_name` directly (defaults to "internal")

**Problem:**
- Existing deployments use `${vnet_name}-${internal_nsg_name}` pattern (e.g., "g1-internal")
- The module creates "internal" instead of "g1-internal"

**Desired behavior:**
- NSG should be named `${local.resolved_vnet_name}-${var.internal_nsg_name}` to maintain consistency
- This ensures the NSG name includes the VNet prefix like other resources

## Requested Changes

Please update the module to:

1. **NAT Gateway Public IP naming:**
   - Change the default naming from `${local.resolved_vnet_name}-nat-pip` to `${local.resolved_vnet_name}-nat-gateway-pip`
   - Keep the behavior when `nat_gateway_name` is provided: `${var.nat_gateway_name}-pip`

2. **NAT Gateway naming:**
   - Change the default naming from `${local.resolved_vnet_name}-nat` to `${local.resolved_vnet_name}-nat-gateway`
   - Keep the behavior when `nat_gateway_name` is provided: use that name directly

3. **Internal NSG naming (BACKWARD COMPATIBLE):**
   - **IMPORTANT:** Add a new variable `internal_nsg_use_vnet_prefix` (default: `true`) to control NSG naming
   - When `internal_nsg_use_vnet_prefix = true`: NSG name is `${local.resolved_vnet_name}-${var.internal_nsg_name}`
   - When `internal_nsg_use_vnet_prefix = false`: NSG name is `var.internal_nsg_name` (current behavior for backward compatibility)
   - This ensures existing deployments (like metaverse with `internal_nsg_name = "internal"`) continue to work without changes

## Files to Update

The changes should be made in:
- `variables.tf` - Add new variable `internal_nsg_use_vnet_prefix` (type: bool, default: true)
- `main.tf` - Update resource naming logic for:
  - `azurerm_public_ip.nat[0]` (NAT Gateway Public IP)
  - `azurerm_nat_gateway.main[0]` (NAT Gateway)
  - `azurerm_network_security_group.internal[0]` (Internal NSG - with conditional logic)

## Example

**Before:**
```hcl
# NAT Gateway Public IP
resource "azurerm_public_ip" "nat" {
  name = var.nat_gateway_name != null ? "${var.nat_gateway_name}-pip" : "${local.resolved_vnet_name}-nat-pip"
  # ...
}

# NAT Gateway
resource "azurerm_nat_gateway" "main" {
  name = var.nat_gateway_name != null ? var.nat_gateway_name : "${local.resolved_vnet_name}-nat"
  # ...
}

# NSG
resource "azurerm_network_security_group" "internal" {
  name = var.internal_nsg_name
  # ...
}
```

**After:**
```hcl
# In variables.tf - Add new variable
variable "internal_nsg_use_vnet_prefix" {
  type        = bool
  default     = true
  description = "Whether to prefix the internal NSG name with the VNet name. Set to false for backward compatibility with existing deployments."
}

# NAT Gateway Public IP
resource "azurerm_public_ip" "nat" {
  name = var.nat_gateway_name != null ? "${var.nat_gateway_name}-pip" : "${local.resolved_vnet_name}-nat-gateway-pip"
  # ...
}

# NAT Gateway
resource "azurerm_nat_gateway" "main" {
  name = var.nat_gateway_name != null ? var.nat_gateway_name : "${local.resolved_vnet_name}-nat-gateway"
  # ...
}

# NSG - with backward compatibility
resource "azurerm_network_security_group" "internal" {
  name = var.internal_nsg_use_vnet_prefix ? "${local.resolved_vnet_name}-${var.internal_nsg_name}" : var.internal_nsg_name
  # ...
}
```

## Benefits

1. **Backward compatibility:** Existing deployments can set `internal_nsg_use_vnet_prefix = false` to maintain current behavior
2. **Consistency:** New deployments default to consistent naming with VNet prefix
3. **Predictability:** Users can rely on consistent naming without needing to set custom names
4. **Migration-friendly:** Easier to migrate from local modules that used these naming patterns
5. **No breaking changes:** Existing configurations (like metaverse) continue to work by setting `internal_nsg_use_vnet_prefix = false`

## Backward Compatibility

**For existing deployments (like metaverse):**
- They can add `internal_nsg_use_vnet_prefix = false` to maintain current NSG naming
- NAT Gateway naming changes only affect new deployments (when `nat_gateway_name` is null)
- If an existing deployment already has resources with the old names, they can:
  - Set `nat_gateway_name` explicitly to match existing resources, OR
  - Accept the new naming and migrate (resources will be recreated)

**Example for backward compatibility:**
```hcl
module "vpc_metaverse" {
  source = "github.com/sipherxyz/terraform-azurerm-network"
  
  # ... other config ...
  
  # Maintain existing NSG name "internal" (not "metaverse-internal")
  internal_nsg_use_vnet_prefix = false
  
  # Or set explicit names to match existing resources
  nat_gateway_name = "metaverse-nat"  # if it already exists with this name
}
```

## Testing

After making the changes, verify that:
1. When `nat_gateway_name` is null, NAT Gateway is named `${vnet_name}-nat-gateway` and Public IP is `${vnet_name}-nat-gateway-pip`
2. When `nat_gateway_name` is provided, it uses that name with `-pip` suffix for Public IP
3. When `internal_nsg_use_vnet_prefix = true` (default), NSG is named `${vnet_name}-${internal_nsg_name}`
4. When `internal_nsg_use_vnet_prefix = false`, NSG is named `${internal_nsg_name}` (backward compatible)
5. Existing deployments with `internal_nsg_use_vnet_prefix = false` continue to work without resource recreation

