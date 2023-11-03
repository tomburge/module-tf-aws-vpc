# Outputs
output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for flow logs"
  value       = try(module.flow_logs_log_group[0].name, null)
}

output "dhcp_options" {
  description = "The DHCP Options of the VPC"
  value       = aws_vpc_dhcp_options.this
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = try(aws_internet_gateway.this[0].id, null)
}

output "isolated_route_table_ids" {
  description = "The IDs of the isolated route tables"
  value       = aws_route_table.isolated.*.id
}

output "isolated_subnets" {
  description = "Information about the isolated subnets"
  value = {
    ids                = aws_subnet.isolated.*.id
    cidr_blocks        = aws_subnet.isolated.*.cidr_block
    availability_zones = aws_subnet.isolated.*.availability_zone
  }
}

output "nat_gateways" {
  description = "Information about the NAT Gateways"
  value = var.role == "egress" ? {
    ids         = aws_nat_gateway.this.*.id
    elastic_ips = aws_eip.nat.*.id
  } : null
}

output "private_route_table_ids" {
  description = "The IDs of the private route tables"
  value       = aws_route_table.private.*.id
}

output "private_subnets" {
  description = "Information about the private subnets"
  value = {
    ids                = aws_subnet.private.*.id
    cidr_blocks        = aws_subnet.private.*.cidr_block
    availability_zones = aws_subnet.private.*.availability_zone
  }
}

output "public_route_table_ids" {
  description = "The IDs of the public route tables"
  value       = aws_route_table.public.*.id
}

output "public_subnets" {
  description = "Information about the public subnets"
  value = {
    ids                = aws_subnet.public.*.id
    cidr_blocks        = aws_subnet.public.*.cidr_block
    availability_zones = aws_subnet.public.*.availability_zone
  }
}

output "s3_flow_log_bucket" {
  description = "The S3 bucket for flow logs"
  value       = try(module.flow_logs_bucket[0], null)
}

output "s3_flow_log_bucket_arn" {
  description = "The ARN of the S3 bucket for flow logs"
  value       = try(module.flow_logs_bucket[0].bucket_arn, null)
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}
