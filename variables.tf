# Variables
variable "az_count" {
  description = "The number of Availability Zones."
  type        = number
}

variable "cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
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

variable "flow_log_config" {
  type = object({
    s3 = optional(object({
      create_bucket   = optional(bool)
      arn             = optional(string)
      force_destroy   = optional(bool)
      traffic_type    = string
      max_aggregation = number
      access_log_config = object({
        target_bucket = string
        target_prefix = string
      })
    }))
    cloudwatch_logs = optional(object({
      create_log_group  = optional(bool)
      force_destroy     = optional(bool)
      traffic_type      = string
      max_aggregation   = number
      retention_in_days = optional(number)
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

variable "instance_tenancy" {
  description = "The Instance Tenancy for the VPC."
  type        = string
  default     = null
}

variable "isolated_bits" {
  description = "The number of Availability Zones."
  type        = number
}

variable "name" {
  type = string
}

variable "net_metrics" {
  description = "The Network Address Usage Metrics for the VPC."
  type        = bool
  default     = null
}

variable "private_per_az" {
  description = "The number of Private Subnets."
  type        = number
}

variable "private_bits" {
  description = "The number of Private Subnet Bits."
  type        = number
}

variable "public_bits" {
  description = "The number of Public Subnet Bits."
  type        = number
  default     = 0
}

variable "role" {
  description = "Role of the VPC (ingress, egress, private)"
  type        = string
}

variable "tags" {
  type = map(string)
}
