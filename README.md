# terraform-azurerm-network

## Create a comprehensive network in Azure

This Terraform module deploys a Virtual Network in Azure with a subnet or a set of subnets passed in as input parameters. The module now supports advanced networking features including:

- **NAT Gateway**: Provides outbound internet connectivity for subnets
- **VPN Gateway**: Enables site-to-site VPN connections with remote networks
- **Network Security Groups (NSG)**: Provides network-level traffic filtering

This module is designed to be similar to the AWS VPC module, providing a comprehensive networking solution for Azure.

## Notice on Upgrade to V5.x

In v5.0.0, we would make `var.use_for_each` a required variable so the users must set the value explicitly. For whom are maintaining the existing infrastructure that was created with `count` should use `false`, for those who are creating a new stack, we encourage them to use `true`.

V5.0.0 is a major version upgrade. Extreme caution must be taken during the upgrade to avoid resource replacement and downtime by accident.

Running the `terraform plan` first to inspect the plan is strongly advised.

## Notice on Upgrade to V4.x

We've added a CI pipeline for this module to speed up our code review and to enforce a high code quality standard, if you want to contribute by submitting a pull request, please read [Pre-Commit & Pr-Check & Test](#Pre-Commit--Pr-Check--Test) section, or your pull request might be rejected by CI pipeline.

A pull request will be reviewed when it has passed Pre Pull Request Check in the pipeline, and will be merged when it has passed the acceptance tests. Once the ci Pipeline failed, please read the pipeline's output, thanks for your cooperation.

V4.0.0 is a major version upgrade. Extreme caution must be taken during the upgrade to avoid resource replacement and downtime by accident.

Running the `terraform plan` first to inspect the plan is strongly advised.

## Usage

### Basic Usage

```hcl
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "my-resources"
  location = "West Europe"
}

module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.example.name
  address_spaces      = ["10.0.0.0/16", "10.2.0.0/16"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_names        = ["subnet1", "subnet2", "subnet3"]

  subnet_service_endpoints = {
    "subnet1" : ["Microsoft.Sql"],
    "subnet2" : ["Microsoft.Sql"],
    "subnet3" : ["Microsoft.Sql"]
  }
  use_for_each = true
  tags = {
    environment = "dev"
    costcenter  = "it"
  }

  depends_on = [azurerm_resource_group.example]
}
```

### Complete Example with NAT Gateway, VPN Gateway, and NSG

```hcl
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "my-resources"
  location = "West Europe"
}

module "network" {
  source              = "Azure/network/azurerm"
  name                = "production-vnet"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_spaces      = ["10.0.0.0/16"]
  subnet_names        = ["subnet1", "subnet2", "subnet3"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  use_for_each        = true

  subnet_service_endpoints = {
    "subnet1" = ["Microsoft.Sql", "Microsoft.ContainerRegistry", "Microsoft.Storage"]
    "subnet2" = ["Microsoft.Sql", "Microsoft.ContainerRegistry", "Microsoft.Storage"]
    "subnet3" = ["Microsoft.Sql", "Microsoft.ContainerRegistry", "Microsoft.Storage"]
  }

  # NAT Gateway Configuration
  enable_nat_gateway                  = true
  nat_gateway_subnet_names            = ["subnet1", "subnet2", "subnet3"]
  nat_gateway_idle_timeout_in_minutes = 10

  # VPN Gateway Configuration
  enable_vpn_gateway     = true
  gateway_subnet_cidr    = "10.0.4.0/27"
  vpn_gateway_sku        = "VpnGw1"
  vpn_gateway_enable_bgp = true
  vpn_shared_key         = var.vpn_shared_key
  remote_gateway_ip      = "1.2.3.4"
  remote_address_spaces  = ["192.168.0.0/16"]
  remote_gateway_name    = "on-premises-gateway"
  vpn_connection_name    = "on-premises-connection"

  # Internal NSG Configuration
  enable_internal_nsg                = true
  internal_nsg_name                  = "internal"
  internal_nsg_source_address_prefix = ["10.0.0.0/16"]

  tags = {
    environment = "production"
    costcenter  = "it"
    Terraform   = "true"
  }

  depends_on = [azurerm_resource_group.example]
}
```

### NAT Gateway Only

```hcl
module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.example.name
  address_spaces      = ["10.0.0.0/16"]
  subnet_names        = ["subnet1", "subnet2"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24"]
  use_for_each        = true

  # Enable NAT Gateway for specific subnets
  enable_nat_gateway                  = true
  nat_gateway_subnet_names            = ["subnet1", "subnet2"]
  nat_gateway_idle_timeout_in_minutes = 4

  tags = {
    environment = "dev"
  }
}
```

### VPN Gateway Only

```hcl
module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.example.name
  address_spaces      = ["10.0.0.0/16"]
  subnet_names        = ["subnet1"]
  subnet_prefixes     = ["10.0.1.0/24"]
  use_for_each        = true

  # Enable VPN Gateway
  enable_vpn_gateway     = true
  gateway_subnet_cidr    = "10.0.4.0/27"  # Required: dedicated subnet for gateway
  vpn_gateway_sku        = "VpnGw1"
  vpn_gateway_enable_bgp = false
  vpn_shared_key         = var.vpn_shared_key
  remote_gateway_ip      = "203.0.113.1"
  remote_address_spaces  = ["192.168.0.0/16"]

  tags = {
    environment = "dev"
  }
}
```

### Network Security Group Only

```hcl
module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.example.name
  address_spaces      = ["10.0.0.0/16"]
  subnet_names        = ["subnet1", "subnet2", "subnet3"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  use_for_each        = true

  # Enable Internal NSG
  enable_internal_nsg                = true
  internal_nsg_name                  = "internal-nsg"
  internal_nsg_source_address_prefix = ["10.0.0.0/16", "172.16.0.0/12"]

  tags = {
    environment = "dev"
  }
}
```

## Enable or disable tracing tags

We're using [BridgeCrew Yor](https://github.com/bridgecrewio/yor) and [yorbox](https://github.com/lonegunmanb/yorbox) to help manage tags consistently across infrastructure as code (IaC) frameworks. In this module you might see tags like:

```hcl
resource "azurerm_resource_group" "rg" {
  location = "eastus"
  name     = random_pet.name
  tags = merge(var.tags, (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_git_commit           = "3077cc6d0b70e29b6e106b3ab98cee6740c916f6"
    avm_git_file             = "main.tf"
    avm_git_last_modified_at = "2023-05-05 08:57:54"
    avm_git_org              = "lonegunmanb"
    avm_git_repo             = "terraform-yor-tag-test-module"
    avm_yor_trace            = "a0425718-c57d-401c-a7d5-f3d88b2551a4"
  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/))
}
```

To enable tracing tags, set the variable to true:

```hcl
module "example" {
  source               = <module_source>
  ...
  tracing_tags_enabled = true
}
```

The `tracing_tags_enabled` is default to `false`.

To customize the prefix for your tracing tags, set the `tracing_tags_prefix` variable value in your Terraform configuration:

```hcl
module "example" {
  source              = <module_source>
  ...
  tracing_tags_prefix = "custom_prefix_"
}
```

The actual applied tags would be:

```text
{
  custom_prefix_git_commit           = "3077cc6d0b70e29b6e106b3ab98cee6740c916f6"
  custom_prefix_git_file             = "main.tf"
  custom_prefix_git_last_modified_at = "2023-05-05 08:57:54"
  custom_prefix_git_org              = "lonegunmanb"
  custom_prefix_git_repo             = "terraform-yor-tag-test-module"
  custom_prefix_yor_trace            = "a0425718-c57d-401c-a7d5-f3d88b2551a4"
}
```

## Notice to contributor

Thanks for your contribution! This module was created before Terraform introduce `for_each`, and according to the [document](https://developer.hashicorp.com/terraform/language/meta-arguments/count#when-to-use-for_each-instead-of-count):

>If your instances are almost identical, `count` is appropriate. If some of their arguments need distinct values that can't be directly derived from an integer, it's safer to use `for_each`.

This module contains resources with `count` meta-argument, but if we change `count` to `for_each` directly, it would require heavily manually state move operations with extremely caution, or the users who are maintaining existing infrastructure would face potential breaking change.

This module replicated a new `azurerm_subnet` which used `for_each`, and we provide a new toggle variable named `use_for_each`, this toggle is a switcher between `count` set and `for_each` set. Now user can set `var.use_for_each` to `true` to use `for_each`, and users who're maintaining existing resources could keep this toggle `false` to avoid potential breaking change. If you'd like to make changes to subnet resource, make sure that you've change both `resource` blocks. Thanks for your cooperation.

## Pre-Commit & Pr-Check & Test

### Configurations

- [Configure Terraform for Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/terraform-install-configure)

We assumed that you have setup service principal's credentials in your environment variables like below:

```shell
export ARM_SUBSCRIPTION_ID="<azure_subscription_id>"
export ARM_TENANT_ID="<azure_subscription_tenant_id>"
export ARM_CLIENT_ID="<service_principal_appid>"
export ARM_CLIENT_SECRET="<service_principal_password>"
```

On Windows Powershell:

```shell
$env:ARM_SUBSCRIPTION_ID="<azure_subscription_id>"
$env:ARM_TENANT_ID="<azure_subscription_tenant_id>"
$env:ARM_CLIENT_ID="<service_principal_appid>"
$env:ARM_CLIENT_SECRET="<service_principal_password>"
```

We provide a docker image to run the pre-commit checks and tests for you: `mcr.microsoft.com/azterraform:latest`

To run the pre-commit task, we can run the following command:

```shell
$ docker run --rm -v $(pwd):/src -w /src mcr.microsoft.com/azterraform:latest make pre-commit
```

On Windows Powershell:

```shell
$ docker run --rm -v ${pwd}:/src -w /src mcr.microsoft.com/azterraform:latest make pre-commit
```

In pre-commit task, we will:

1. Run `terraform fmt -recursive` command for your Terraform code.
2. Run `terrafmt fmt -f` command for markdown files and go code files to ensure that the Terraform code embedded in these files are well formatted.
3. Run `go mod tidy` and `go mod vendor` for test folder to ensure that all the dependencies have been synced.
4. Run `gofmt` for all go code files.
5. Run `gofumpt` for all go code files.
6. Run `terraform-docs` on `README.md` file, then run `markdown-table-formatter` to format markdown tables in `README.md`.

Then we can run the pr-check task to check whether our code meets our pipeline's requirement(We strongly recommend you run the following command before you commit):

```shell
$ docker run --rm -v $(pwd):/src -w /src -e TFLINT_CONFIG=.tflint_alt.hcl mcr.microsoft.com/azterraform:latest make pr-check
```

On Windows Powershell:

```shell
$ docker run --rm -v ${pwd}:/src -w /src -e TFLINT_CONFIG=.tflint_alt.hcl mcr.microsoft.com/azterraform:latest make pr-check
```

To run the e2e-test, we can run the following command:

```text
docker run --rm -v $(pwd):/src -w /src -e ARM_SUBSCRIPTION_ID -e ARM_TENANT_ID -e ARM_CLIENT_ID -e ARM_CLIENT_SECRET mcr.microsoft.com/azterraform:latest make e2e-test
```

On Windows Powershell:

```text
docker run --rm -v ${pwd}:/src -w /src -e ARM_SUBSCRIPTION_ID -e ARM_TENANT_ID -e ARM_CLIENT_ID -e ARM_CLIENT_SECRET mcr.microsoft.com/azterraform:latest make e2e-test
```

## Prerequisites

- [Docker](https://www.docker.com/community-edition#/download)

## Authors

Originally created by [Eugene Chuvyrov](http://github.com/echuvyrov)

## License

[MIT](LICENSE)

## Important Notes

### Provider Version

This module requires **azurerm provider >= 4.0**. Make sure to update your provider version:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}
```

### Gateway Subnet Requirements

When enabling VPN Gateway, you **must** provide a `gateway_subnet_cidr`. The gateway subnet:
- Must be named "GatewaySubnet" (automatically handled by the module)
- Should typically be /27 or larger
- Must be within your vNet address space
- Cannot overlap with other subnets

### NAT Gateway Considerations

- NAT Gateways are created per subnet (one NAT Gateway per subnet in `nat_gateway_subnet_names`)
- Each NAT Gateway requires a Standard SKU Public IP (automatically created)
- NAT Gateways are zone-redundant by default (zones 1, 2, 3)
- NAT Gateway idle timeout can be configured (default: 4 minutes, max: 16 minutes)

### VPN Gateway Considerations

- VPN Gateway creation can take 30-45 minutes
- The gateway subnet must be dedicated (no other resources)
- BGP is optional but recommended for dynamic routing
- The pre-shared key (`vpn_shared_key`) must match on both sides of the connection

### Network Security Groups

- When enabled, NSG is automatically associated with all subnets
- Default rules allow internal traffic within the specified address prefixes
- Additional custom rules can be added outside this module if needed

## Features

### NAT Gateway

The module can create NAT Gateways to provide outbound internet connectivity for your subnets. NAT Gateways are created with:
- Standard SKU Public IP addresses
- Configurable idle timeout (default: 4 minutes)
- Zone-redundant deployment (zones 1, 2, 3)
- Automatic association with specified subnets

**Key Variables:**
- `enable_nat_gateway`: Set to `true` to enable NAT Gateway creation
- `nat_gateway_subnet_names`: List of subnet names where NAT Gateway should be attached
- `nat_gateway_idle_timeout_in_minutes`: Idle timeout in minutes (default: 4)

### VPN Gateway

The module supports creating VPN Gateways for site-to-site connections:
- Supports all VPN Gateway SKUs (VpnGw1, VpnGw2, VpnGw3, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ)
- BGP support for dynamic routing
- Automatic creation of Local Network Gateway for remote networks
- VPN Connection with pre-shared key authentication

**Key Variables:**
- `enable_vpn_gateway`: Set to `true` to enable VPN Gateway
- `gateway_subnet_cidr`: CIDR block for the gateway subnet (required, typically /27)
- `vpn_gateway_sku`: SKU for the VPN Gateway (default: "VpnGw1")
- `vpn_gateway_enable_bgp`: Enable BGP routing (default: false)
- `vpn_shared_key`: Pre-shared key for VPN connection (sensitive)
- `remote_gateway_ip`: Public IP of the remote gateway
- `remote_address_spaces`: Address spaces of the remote network

### Network Security Groups

The module can create and associate Network Security Groups with all subnets:
- Automatic rule creation for internal traffic
- Configurable source address prefixes
- Rules for both inbound and outbound traffic

**Key Variables:**
- `enable_internal_nsg`: Set to `true` to enable NSG creation
- `internal_nsg_name`: Name of the NSG (default: "internal")
- `internal_nsg_source_address_prefix`: List of allowed source address prefixes (defaults to vNet address space if empty)

## Outputs

The module provides comprehensive outputs for all created resources:

- `vnet_id`: ID of the Virtual Network
- `vnet_name`: Name of the Virtual Network
- `vnet_address_space`: Address space of the Virtual Network
- `vnet_location`: Location of the Virtual Network
- `vnet_subnets`: List of subnet IDs
- `gateway_subnet_id`: ID of the gateway subnet (if VPN Gateway is enabled)
- `nat_gateway_ids`: Map of NAT Gateway IDs keyed by subnet name
- `nat_gateway_public_ip_addresses`: Map of NAT Gateway Public IP addresses
- `vpn_gateway_id`: ID of the VPN Gateway (if enabled)
- `vpn_gateway_public_ip_address`: Public IP address of the VPN Gateway
- `local_network_gateway_id`: ID of the Local Network Gateway
- `vpn_connection_id`: ID of the VPN Connection
- `network_security_group_id`: ID of the Network Security Group (if enabled)

## Common Use Cases

### Hybrid Cloud Connection (Azure to AWS)

```hcl
module "network" {
  source              = "Azure/network/azurerm"
  name                = "hybrid-vnet"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_spaces      = ["10.0.0.0/16"]
  subnet_names        = ["subnet1", "subnet2"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24"]
  use_for_each        = true

  # VPN Gateway for AWS connection
  enable_vpn_gateway     = true
  gateway_subnet_cidr    = "10.0.4.0/27"
  vpn_gateway_sku        = "VpnGw1"
  vpn_gateway_enable_bgp = true
  vpn_shared_key         = var.vpn_shared_key
  remote_gateway_ip      = var.aws_vpn_gateway_ip
  remote_address_spaces  = [var.aws_vpc_cidr]
  remote_gateway_name    = "aws-vpc-gateway"
  vpn_connection_name    = "aws-connection"

  tags = {
    environment = "production"
  }
}
```

### Private Subnets with NAT Gateway

```hcl
module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.example.name
  address_spaces      = ["10.0.0.0/16"]
  subnet_names        = ["private-subnet-1", "private-subnet-2"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24"]
  use_for_each        = true

  # NAT Gateway for outbound internet access
  enable_nat_gateway                  = true
  nat_gateway_subnet_names            = ["private-subnet-1", "private-subnet-2"]
  nat_gateway_idle_timeout_in_minutes = 10

  tags = {
    environment = "production"
  }
}
```

### Secure Network with NSG

```hcl
module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.example.name
  address_spaces      = ["10.0.0.0/16"]
  subnet_names        = ["app-subnet", "db-subnet", "web-subnet"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  use_for_each        = true

  # Network Security Group for traffic filtering
  enable_internal_nsg                = true
  internal_nsg_name                  = "secure-nsg"
  internal_nsg_source_address_prefix = ["10.0.0.0/16", "172.16.0.0/12"]

  tags = {
    environment = "production"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_subnet.subnet_count](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.subnet_for_each](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_public_ip.nat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) | resource |
| [azurerm_nat_gateway_public_ip_association.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) | resource |
| [azurerm_subnet_nat_gateway_association.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association) | resource |
| [azurerm_public_ip.vpn_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_virtual_network_gateway.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) | resource |
| [azurerm_local_network_gateway.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway) | resource |
| [azurerm_virtual_network_gateway_connection.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) | resource |
| [azurerm_network_security_group.internal](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.allow_internal_inbound](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.allow_internal_outbound](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_subnet_network_security_group_association.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_resource_group.network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | The address space that is used by the virtual network. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_address_spaces"></a> [address\_spaces](#input\_address\_spaces) | The list of the address spaces that is used by the virtual network. | `list(string)` | `[]` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | The DNS servers to be used with vNet. | `list(string)` | `[]` | no |
| <a name="input_location"></a> [location](#input\_location) | The location/region where the virtual network is created. If provided, this will override resource_group_location. For backward compatibility. | `string` | `null` | no |
| <a name="input_resource_group_location"></a> [resource\_group\_location](#input\_resource\_group\_location) | The location/region where the virtual network is created. Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of an existing resource group to be imported. | `string` | n/a | yes |
| <a name="input_subnet_delegation"></a> [subnet\_delegation](#input\_subnet\_delegation) | `service_delegation` blocks for `azurerm_subnet` resource, subnet names as keys, list of delegation blocks as value, more details about delegation block could be found at the [document](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet#delegation). | <pre>map(list(object({<br>    name = string<br>    service_delegation = object({<br>      name    = string<br>      actions = optional(list(string))<br>    })<br>  })))</pre> | `{}` | no |
| <a name="input_subnet_enforce_private_link_endpoint_network_policies"></a> [subnet\_enforce\_private\_link\_endpoint\_network\_policies](#input\_subnet\_enforce\_private\_link\_endpoint\_network\_policies) | A map with key (string) `subnet name`, value (bool) `true` or `false` to indicate enable or disable network policies for the private link endpoint on the subnet. Default value is false. | `map(bool)` | `{}` | no |
| <a name="input_subnet_names"></a> [subnet\_names](#input\_subnet\_names) | A list of public subnets inside the vNet. | `list(string)` | <pre>[<br>  "subnet1"<br>]</pre> | no |
| <a name="input_subnet_prefixes"></a> [subnet\_prefixes](#input\_subnet\_prefixes) | The address prefix to use for the subnet. | `list(string)` | <pre>[<br>  "10.0.1.0/24"<br>]</pre> | no |
| <a name="input_subnet_service_endpoints"></a> [subnet\_service\_endpoints](#input\_subnet\_service\_endpoints) | A map with key (string) `subnet name`, value (list(string)) to indicate enabled service endpoints on the subnet. Default value is []. | `map(list(string))` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | The tags to associate with your network and subnets. | `map(string)` | <pre>{<br>  "environment": "dev"<br>}</pre> | no |
| <a name="input_tracing_tags_enabled"></a> [tracing\_tags\_enabled](#input\_tracing\_tags\_enabled) | Whether enable tracing tags that generated by BridgeCrew Yor. | `bool` | `false` | no |
| <a name="input_tracing_tags_prefix"></a> [tracing\_tags\_prefix](#input\_tracing\_tags\_prefix) | Default prefix for generated tracing tags | `string` | `"avm_"` | no |
| <a name="input_use_for_each"></a> [use\_for\_each](#input\_use\_for\_each) | Use `for_each` instead of `count` to create multiple resource instances. | `bool` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the vnet to create. If provided, this will override vnet_name. For backward compatibility. | `string` | `null` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | Name of the vnet to create. | `string` | `"acctvnet"` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Should a NAT Gateway be created for outbound internet access? | `bool` | `false` | no |
| <a name="input_nat_gateway_subnet_names"></a> [nat\_gateway\_subnet\_names](#input\_nat\_gateway\_subnet\_names) | List of subnet names where NAT Gateway should be attached. NAT Gateway will be created for each subnet. | `list(string)` | `[]` | no |
| <a name="input_nat_gateway_idle_timeout_in_minutes"></a> [nat\_gateway\_idle\_timeout\_in\_minutes](#input\_nat\_gateway\_idle\_timeout\_in\_minutes) | The idle timeout in minutes for the NAT Gateway. Defaults to 4. | `number` | `4` | no |
| <a name="input_nat_gateway_name"></a> [nat\_gateway\_name](#input\_nat\_gateway\_name) | Name of the NAT Gateway. If not provided, will be generated as '{vnet_name}-nat-{subnet_name}'. | `string` | `null` | no |
| <a name="input_enable_vpn_gateway"></a> [enable\_vpn\_gateway](#input\_enable\_vpn\_gateway) | Should a VPN Gateway be created? | `bool` | `false` | no |
| <a name="input_gateway_subnet_cidr"></a> [gateway\_subnet\_cidr](#input\_gateway\_subnet\_cidr) | CIDR block for the gateway subnet. Required if enable_vpn_gateway is true. | `string` | `null` | no |
| <a name="input_vpn_gateway_sku"></a> [vpn\_gateway\_sku](#input\_vpn\_gateway\_sku) | The SKU of the VPN Gateway. Valid values are: VpnGw1, VpnGw2, VpnGw3, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ. | `string` | `"VpnGw1"` | no |
| <a name="input_vpn_gateway_enable_bgp"></a> [vpn\_gateway\_enable\_bgp](#input\_vpn\_gateway\_enable\_bgp) | Should BGP be enabled on the VPN Gateway? | `bool` | `false` | no |
| <a name="input_vpn_gateway_name"></a> [vpn\_gateway\_name](#input\_vpn\_gateway\_name) | Name of the VPN Gateway. If not provided, will be generated as '{vnet_name}-vpn-gateway'. | `string` | `null` | no |
| <a name="input_vpn_shared_key"></a> [vpn\_shared\_key](#input\_vpn\_shared\_key) | The shared key for the VPN connection. Required if enable_vpn_gateway is true. | `string` | `null` | no |
| <a name="input_remote_gateway_ip"></a> [remote\_gateway\_ip](#input\_remote\_gateway\_ip) | The public IP address of the remote gateway. Required if enable_vpn_gateway is true. | `string` | `null` | no |
| <a name="input_remote_address_spaces"></a> [remote\_address\_spaces](#input\_remote\_address\_spaces) | The address spaces of the remote network. Required if enable_vpn_gateway is true. | `list(string)` | `[]` | no |
| <a name="input_remote_gateway_name"></a> [remote\_gateway\_name](#input\_remote\_gateway\_name) | Name of the Local Network Gateway (remote gateway). If not provided, will be generated as '{vnet_name}-remote-gateway'. | `string` | `null` | no |
| <a name="input_vpn_connection_name"></a> [vpn\_connection\_name](#input\_vpn\_connection\_name) | Name of the VPN connection. If not provided, will be generated as '{vnet_name}-vpn-connection'. | `string` | `null` | no |
| <a name="input_enable_internal_nsg"></a> [enable\_internal\_nsg](#input\_enable\_internal\_nsg) | Should an internal Network Security Group be created and associated with subnets? | `bool` | `false` | no |
| <a name="input_internal_nsg_name"></a> [internal\_nsg\_name](#input\_internal\_nsg\_name) | Name of the internal Network Security Group. | `string` | `"internal"` | no |
| <a name="input_internal_nsg_source_address_prefix"></a> [internal\_nsg\_source\_address\_prefix](#input\_internal\_nsg\_source\_address\_prefix) | List of source address prefixes allowed in the NSG rules. If empty, will default to the vNet address space. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_vnet_address_space"></a> [vnet\_address\_space](#output\_vnet\_address\_space) | The address space of the newly created vNet |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | The id of the newly created vNet |
| <a name="output_vnet_location"></a> [vnet\_location](#output\_vnet\_location) | The location of the newly created vNet |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | The name of the newly created vNet |
| <a name="output_vnet_subnets"></a> [vnet\_subnets](#output\_vnet\_subnets) | The ids of subnets created inside the newly created vNet |
| <a name="output_gateway_subnet_id"></a> [gateway\_subnet\_id](#output\_gateway\_subnet\_id) | The id of the gateway subnet (if VPN Gateway is enabled) |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | Map of NAT Gateway IDs, keyed by subnet name |
| <a name="output_nat_gateway_public_ip_addresses"></a> [nat\_gateway\_public\_ip\_addresses](#output\_nat\_gateway\_public\_ip\_addresses) | Map of NAT Gateway Public IP addresses, keyed by subnet name |
| <a name="output_vpn_gateway_id"></a> [vpn\_gateway\_id](#output\_vpn\_gateway\_id) | The id of the VPN Gateway (if enabled) |
| <a name="output_vpn_gateway_public_ip_address"></a> [vpn\_gateway\_public\_ip\_address](#output\_vpn\_gateway\_public\_ip\_address) | The public IP address of the VPN Gateway (if enabled) |
| <a name="output_local_network_gateway_id"></a> [local\_network\_gateway\_id](#output\_local\_network\_gateway\_id) | The id of the Local Network Gateway (if VPN Gateway is enabled) |
| <a name="output_vpn_connection_id"></a> [vpn\_connection\_id](#output\_vpn\_connection\_id) | The id of the VPN Connection (if enabled) |
| <a name="output_network_security_group_id"></a> [network\_security\_group\_id](#output\_network\_security\_group\_id) | The id of the internal Network Security Group (if enabled) |
<!-- END_TF_DOCS -->
