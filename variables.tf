variable "role" {
  description = "Role of the VPC (ingress, egress, private)"
  type        = string
}

variable "cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "dns_hostnames" {
  description = "The DNS Hostname flag for the VPC."
  type        = bool
  default     = null
}

variable "dns_support" {
  description = "The DNS Support flag for the VPC."
  type        = bool
  default     = null
}

variable "net_metrics" {
  description = "The Network Address Usage Metrics for the VPC."
  type        = bool
  default     = null
}

variable "instance_tenancy" {
  description = "The Instance Tenancy for the VPC."
  type        = string
  default     = null
}

variable "az_count" {
  description = "The number of Availability Zones."
  type        = number
}

variable "isolated_bits" {
  description = "The number of Availability Zones."
  type        = number
}

variable "public_bits" {
  description = "The number of Public Subnet Bits."
  type        = number
  default     = 0
}

variable "private_per_az" {
  description = "The number of Private Subnets."
  type        = number
}

variable "private_bits" {
  description = "The number of Private Subnet Bits."
  type        = number
}

variable "dhcp_options" {
  type = object({
    domain_name          = optional(string)
    domain_name_servers  = optional(list(string))
    ntp_servers          = optional(list(string))
    netbios_name_servers = optional(list(string))
    netbios_node_type    = optional(number)
  })
  default = null
}

variable "flow_log_config" {
  type = object({
    s3 = optional(object({
      create_bucket   = bool
      force_destroy   = bool
      traffic_type    = string
      max_aggregation = number
    }))
    cloudwatch_logs = optional(object({
      create_log_group = bool
      traffic_type     = string
      max_aggregation  = number
    }))
    kinesis_data_firehose = optional(object({
      create_stream   = bool
      traffic_type    = string
      max_aggregation = number
    }))
  })
  default = {
    s3                    = null
    cloudwatch_logs       = null
    kinesis_data_firehose = null
  }
}

variable "tags" {
  type = map(string)
}
