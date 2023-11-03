data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowAssumeRole"
    actions = ["sts:AssumeRole"]
    effect  = ["Allow"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudwatch_flow_log_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    effect    = "Allow"
    resources = ["${module.flow_logs_log_group[0].arn}"]
  }
}

data "aws_iam_policy_document" "s3_flow_log_policy" {
  count = try(var.flow_log_config.s3.create_bucket, false) ? 1 : 0
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetBucketAcl"
    ]
    effect = "Allow"
    resources = [
      "${module.flow_logs_bucket[0].bucket_arn}/*",
      "${module.flow_logs_bucket[0].bucket_arn}"
    ]
  }
}
