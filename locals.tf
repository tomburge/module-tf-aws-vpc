# Locals
locals {
  selected_azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_count         = var.az_count
  isolated_count       = var.az_count
  default_dhcp_options = null
  dhcp_options         = var.dhcp_options != null ? var.dhcp_options : local.default_dhcp_options
}
