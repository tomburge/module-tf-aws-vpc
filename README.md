# module-tf-aws-vpc

## What does this module do?

-   Creates VPC
-   Creates 3 Types of Subnets (depending on role)
    -   Isolated
    -   Private
    -   Public
-   Creates Subnets in 1, 2, or 3 Availability Zones
-   Creates Route Tables for Subnet Types by Availability Zone
-   Associates Subnets with Route Table by Availability Zone
-   Creates Internet Gateway (depending on role)
-   Creates NAT Gateways (depending on role and number of Public Subnets)
-   Creates S3 Flow Logs with S3 Bucket
-   Creates CloudWatch Logs Flow Logs with Log Group and IAM Role/Policy
-   Creates DHCP Options
-   Removes Ingress and Egress Rules from Default Security Group
-   If NAT Gateways exists, creates route in Private Subnet Route Tables by Availability Zone
-   If Internet Gateway exists, creates route in Public Subnet Route Tables by Availability Zone

## Configuration Options:

-   role (string): "ingress" | "egress" | "private"
    -   Ingress - Public, Private, Isolated, Internet Gateway but no NAT Gateway
    -   Egress - Public, Private, Isolated, Internet Gateway and NAT Gateway
    -   Private - Private and Isolated
-   cidr_block (string): "10.0.0.0/16"
-   dns_hostname (bool): true | false
-   dns_support (bool): true | false
-   net_metrics (bool): true | false
-   instance_tenancy (string): "default" | "dedicated"
-   az_count (number): 1 | 2 | 3
-   isolated_bits (number): **varies, see table below**
-   public_bits (number): **varies**
-   private_per_az (number): **varies** NOTE: Creates number of Private Subnets per Availability Zone in az_count
-   private_bits (number): **varies**
-   dhcp_options (object):
    -   domain_name (string): "test.com"
    -   domain_name_servers (list): ["8.8.8.8", "8.8.4.4"]
    -   ntp_servers (list): ["8.8.8.8", "8.8.4.4"]
-   flow_log_config (object):
    -   s3 (object):
        -   create_bucket (bool): true | false **NOTE: false not working yet**
        -   force_destroy (bool): true | false
        -   traffic_type (string): "ALL" | "ACCEPT" | "REJECT"
        -   max_aggregation (number): 60 | 600
    -   cloudwatch_logs (object):
        -   create_log_group (bool): true | false **NOTE: false not working yet**
        -   traffic_type (string): "ALL" | "ACCEPT" | "REJECT"
        -   max_aggregation (number): 60 | 600
-   tags (map): **Example below**

```
tags =  {
	"repo" = "https://github.com/tomburge/module-tf-aws-vpc",
	"terraform" = "true"
}
```

## Example Module Configuration:

```
module  "ingress_vpc" {
	source  =  "github.com/tomburge/module-tf-aws-vpc?ref=main"
	role =  "ingress"
	cidr_block =  "10.0.0.0/16"
	dns_hostnames =  true
	dns_support =  true
	net_metrics =  true
	instance_tenancy =  "default"
	az_count =  2
	isolated_bits =  12
	public_bits =  4
	private_per_az =  2
	private_bits =  4
	dhcp_options =  {
		domain_name  =  "test.com"
		domain_name_servers  = ["8.8.8.8", "8.8.4.4"]
		ntp_servers  = ["8.8.8.8", "8.8.4.4"]
	}
	flow_log_config =  {
		s3  = {
			create_bucket  =  true
			force_destroy  =  true
			traffic_type  =  "ALL"
			max_aggregation  =  600
		}
		cloudwatch_logs  = {
			create_log_group  =  true
			traffic_type  =  "ALL"
			max_aggregation  =  600
		}
	}
	tags = var.default_tags
}
```

## Isolated Subnets Table

Isolated Subnets are intended to be used as subnets where resources such as Transit Gateway attachments live.

| VPC CIDR | Bits | Subnet CIDR |
| -------- | ---- | ----------- |
| /16      | 12   | /28         |
| /17      | 11   | /28         |
| /18      | 10   | /28         |
| /19      | 9    | /28         |
| /20      | 8    | /28         |
| /21      | 7    | /28         |
| /22      | 6    | /28         |
| /23      | 5    | /28         |
| /24      | 4    | /28         |
| /25      | 3    | /28         |
| /26      | 2    | /28         |
| /27      | 1    | /28         |

## What this module doesn't do

No support for IPv6
No support for IPAM
