locals {
  selected_azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_count         = var.az_count
  isolated_count       = var.az_count
  default_dhcp_options = null
  dhcp_options         = var.dhcp_options != null ? var.dhcp_options : local.default_dhcp_options
}

resource "aws_vpc" "this" {
  cidr_block                           = var.cidr_block
  enable_dns_hostnames                 = var.dns_hostnames != null ? var.dns_hostnames : true
  enable_dns_support                   = var.dns_support != null ? var.dns_support : true
  enable_network_address_usage_metrics = var.net_metrics != null ? var.net_metrics : true
  instance_tenancy                     = var.instance_tenancy != "" ? var.instance_tenancy : "default"
  tags                                 = merge({ Name = "${var.role}-vpc" }, var.tags)
}

resource "aws_subnet" "isolated" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, var.isolated_bits, count.index)
  availability_zone = local.selected_azs[count.index % length(local.selected_azs)]
  tags              = merge({ Name = "${var.role}-vpc-isolated-subnet-${count.index + 1}" }, var.tags)
}

resource "aws_subnet" "public" {
  count             = var.role != "private" ? var.az_count : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, var.public_bits, count.index + local.isolated_count)
  availability_zone = local.selected_azs[count.index % length(local.selected_azs)]
  tags              = merge({ Name = "${var.role}-vpc-public-subnet-${count.index + 1}" }, var.tags)
}

resource "aws_subnet" "private" {
  count             = var.private_per_az * var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, var.private_bits, count.index + local.isolated_count + local.public_count)
  availability_zone = local.selected_azs[count.index % length(local.selected_azs)]
  tags              = merge({ Name = "${var.role}-vpc-private-subnet-${count.index + 1}" }, var.tags)
}

resource "aws_route_table" "isolated" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = "${var.role}-vpc-isolated-rt-${count.index + 1}" }, var.tags)
}

resource "aws_route_table" "public" {
  count  = var.role != "private" ? local.public_count : 0
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = "${var.role}-vpc-public-rt-${count.index + 1}" }, var.tags)
}

resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = "${var.role}-vpc-private-rt-${count.index + 1}" }, var.tags)
}

resource "aws_route_table_association" "isolated" {
  count          = var.az_count
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated[count.index % var.az_count].id
}

resource "aws_route_table_association" "public" {
  count          = var.role != "private" ? local.public_count : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index % length(aws_route_table.public)].id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index % length(aws_route_table.private)].id
}

resource "aws_internet_gateway" "this" {
  count  = var.role == "private" ? 0 : 1
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = "${var.role}-vpc-igw" }, var.tags)
}

resource "aws_eip" "nat" {
  count = var.role == "egress" && length(aws_subnet.public) > 0 ? var.az_count : 0
  tags  = merge({ Name = "${var.role}-vpc-nat-eip-${count.index + 1}" }, var.tags)
}

resource "aws_nat_gateway" "this" {
  count         = var.role == "egress" && length(aws_subnet.public) > 0 ? var.az_count : 0
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id
  tags          = merge({ Name = "${var.role}-vpc-nat-gw-${count.index + 1}" }, var.tags)
}

resource "aws_s3_bucket" "flow_logs" {
  count         = try(var.flow_log_config.s3.create_bucket, false) ? 1 : 0
  bucket        = "flow-logs-${var.role}-vpc-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  count = try(var.flow_log_config.cloudwatch_logs.create_log_group, false) ? 1 : 0
  name  = "flow-logs-${var.role}-vpc-${data.aws_caller_identity.current.account_id}"
}

resource "aws_iam_role" "flow_log_role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name               = "flow-logs-${var.role}-vpc-${data.aws_caller_identity.current.account_id}"
}

resource "aws_iam_role_policy" "s3_flow_log_policy" {
  count  = try(var.flow_log_config.s3.create_bucket, false) ? 1 : 0
  role   = aws_iam_role.flow_log_role.id
  policy = data.aws_iam_policy_document.s3_flow_log_policy[count.index].json
}

resource "aws_flow_log" "s3_flow_log" {
  count                    = try(var.flow_log_config.s3.create_bucket, false) ? 1 : 0
  log_destination          = try(var.flow_log_config.s3.arn, aws_s3_bucket.flow_logs[0].arn)
  log_destination_type     = "s3"
  traffic_type             = try(var.flow_log_config.s3.traffic_type, "ALL")
  max_aggregation_interval = try(var.flow_log_config.s3.max_aggregation, 600)
  vpc_id                   = aws_vpc.this.id
}

resource "aws_iam_role_policy" "cloudwatch_flow_log_policy" {
  count  = try(var.flow_log_config.cloudwatch_logs.create_log_group, false) ? 1 : 0
  role   = aws_iam_role.flow_log_role.id
  policy = data.aws_iam_policy_document.cloudwatch_flow_log_policy.json
}

resource "aws_flow_log" "cloudwatch_flow_log" {
  count                    = try(var.flow_log_config.cloudwatch_logs.create_log_group, false) ? 1 : 0
  log_destination          = try(var.flow_log_config.cloudwatch_logs.arn, aws_cloudwatch_log_group.flow_log_group[count.index].arn)
  log_destination_type     = "cloud-watch-logs"
  traffic_type             = try(var.flow_log_config.cloudwatch_logs.traffic_type, "ALL")
  max_aggregation_interval = try(var.flow_log_config.s3.max_aggregation, 600)
  vpc_id                   = aws_vpc.this.id
  iam_role_arn             = aws_iam_role.flow_log_role.arn
}

resource "aws_route" "public_internet_gateway" {
  count                  = var.role != "private" ? local.public_count : 0
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.role == "egress" ? var.private_per_az : 0
  route_table_id         = aws_route_table.private[count.index % length(aws_route_table.private)].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index % var.az_count].id
}

resource "aws_vpc_dhcp_options" "this" {
  count                = local.dhcp_options != null ? 1 : 0
  domain_name          = local.dhcp_options.domain_name
  domain_name_servers  = local.dhcp_options.domain_name_servers
  ntp_servers          = local.dhcp_options.ntp_servers
  netbios_name_servers = local.dhcp_options.netbios_name_servers
  netbios_node_type    = local.dhcp_options.netbios_node_type
  tags                 = merge({ Name = "${var.role}-vpc-dhcp-options" }, var.tags)
}

resource "aws_vpc_dhcp_options_association" "this" {
  count           = local.dhcp_options != null ? 1 : 0
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id
}
