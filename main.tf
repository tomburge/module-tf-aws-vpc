# Resources
resource "aws_vpc" "this" {
  cidr_block                           = var.cidr_block
  enable_dns_hostnames                 = var.dns_hostnames != null ? var.dns_hostnames : true
  enable_dns_support                   = var.dns_support != null ? var.dns_support : true
  enable_network_address_usage_metrics = var.net_metrics != null ? var.net_metrics : true
  instance_tenancy                     = var.instance_tenancy != "" ? var.instance_tenancy : "default"
  tags                                 = merge({ Name = "${var.name}-vpc" }, var.tags)
}

resource "aws_subnet" "isolated" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, var.isolated_bits, count.index)
  availability_zone = local.selected_azs[count.index % length(local.selected_azs)]
  tags              = merge({ Name = "${var.name}-vpc-isolated-subnet-${count.index + 1}" }, var.tags)
}

resource "aws_subnet" "public" {
  count             = var.role != "private" ? var.az_count : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, var.public_bits, count.index + local.isolated_count)
  availability_zone = local.selected_azs[count.index % length(local.selected_azs)]
  tags              = merge({ Name = "${var.name}-vpc-public-subnet-${count.index + 1}" }, var.tags)
}

resource "aws_subnet" "private" {
  count             = var.private_per_az * var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, var.private_bits, count.index + local.isolated_count + local.public_count)
  availability_zone = local.selected_azs[count.index % length(local.selected_azs)]
  tags              = merge({ Name = "${var.name}-vpc-private-subnet-${count.index + 1}" }, var.tags)
}

resource "aws_route_table" "isolated" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = "${var.name}-vpc-isolated-rt-${count.index + 1}" }, var.tags)
}

resource "aws_route_table" "public" {
  count  = var.role != "private" ? local.public_count : 0
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = "${var.name}-vpc-public-rt-${count.index + 1}" }, var.tags)
}

resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = "${var.name}-vpc-private-rt-${count.index + 1}" }, var.tags)
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
  tags   = merge({ Name = "${var.name}-vpc-igw" }, var.tags)
}

resource "aws_eip" "nat" {
  count = var.role == "egress" && length(aws_subnet.public) > 0 ? var.az_count : 0
  tags  = merge({ Name = "${var.name}-vpc-nat-eip-${count.index + 1}" }, var.tags)
}

resource "aws_nat_gateway" "this" {
  count         = var.role == "egress" && length(aws_subnet.public) > 0 ? var.az_count : 0
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id
  tags          = merge({ Name = "${var.name}-vpc-nat-gw-${count.index + 1}" }, var.tags)
}

module "flow_logs_bucket" {
  source        = "github.com/tomburge/module-tf-aws-s3-bucket?ref=main"
  count         = try(var.flow_log_config.s3.create_bucket, false) ? 1 : 0
  bucket_name   = "flow-logs-${var.name}-vpc-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  access_log_config = {
    target_bucket = var.flow_log_config.s3.access_log_config.target_bucket
    target_prefix = var.flow_log_config.s3.access_log_config.target_prefix
  }
}

module "flow_logs_log_group" {
  source         = "github.com/tomburge/module-tf-aws-cloudwatch-loggroup?ref=main"
  count          = try(var.flow_log_config.cloudwatch_logs.create_log_group, false) ? 1 : 0
  name           = "flow-logs-${var.name}-vpc-${data.aws_caller_identity.current.account_id}"
  destroy        = var.flow_log_config.cloudwatch_logs.force_destroy
  retention_days = var.flow_log_config.cloudwatch_logs.retention_days
}

resource "aws_iam_role" "flow_log_role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name               = "flow-logs-${var.name}-vpc-${data.aws_caller_identity.current.account_id}"
}

resource "aws_iam_role_policy" "s3_flow_log_policy" {
  count  = try(var.flow_log_config.s3.create_bucket, false) ? 1 : 0
  role   = aws_iam_role.flow_log_role.id
  policy = data.aws_iam_policy_document.s3_flow_log_policy[count.index].json
}

resource "aws_iam_role_policy" "cloudwatch_flow_log_policy" {
  count  = try(var.flow_log_config.cloudwatch_logs.create_log_group, false) ? 1 : 0
  role   = aws_iam_role.flow_log_role.id
  policy = data.aws_iam_policy_document.cloudwatch_flow_log_policy.json
}

resource "aws_flow_log" "s3_flow_log" {
  count                    = try(var.flow_log_config.s3.create_bucket, false) ? 1 : 0
  log_destination          = module.flow_logs_bucket[0].bucket_arn
  log_destination_type     = "s3"
  traffic_type             = try(var.flow_log_config.s3.traffic_type, "ALL")
  max_aggregation_interval = try(var.flow_log_config.s3.max_aggregation, 600)
  vpc_id                   = aws_vpc.this.id
}

resource "aws_flow_log" "cloudwatch_flow_log" {
  count                    = try(var.flow_log_config.cloudwatch_logs.create_log_group, false) ? 1 : 0
  log_destination          = try(var.flow_log_config.cloudwatch_logs.arn, module.flow_logs_log_group[count.index].arn)
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

resource "aws_route" "nat_gateway_private" {
  count                  = var.role == "egress" ? length(aws_route_table.private) : 0
  route_table_id         = aws_route_table.private[count.index % length(aws_route_table.private)].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index % var.az_count].id
}

resource "aws_route" "nat_gateway_isolated" {
  count                  = var.role == "egress" ? length(aws_route_table.isolated) : 0
  route_table_id         = aws_route_table.isolated[count.index % length(aws_route_table.isolated)].id
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
  tags                 = merge({ Name = "${var.name}-vpc-dhcp-options" }, var.tags)
}

resource "aws_vpc_dhcp_options_association" "this" {
  count           = local.dhcp_options != null ? 1 : 0
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-vpc-default-security-group" }
}
