data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

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

    resources = ["*"]
    effect    = "Allow"
  }
}

data "aws_iam_policy_document" "s3_flow_log_policy" {
  count = try(var.flow_log_config.s3.create_bucket, false) ? 1 : 0
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetBucketAcl"
    ]

    resources = [
      "${module.flow_logs_bucket.bucket_arn}/*",
      "${module.flow_logs_bucket.bucket_arn}"
      # "${aws_s3_bucket.flow_logs[count.index].arn}/*",
      # "${aws_s3_bucket.flow_logs[count.index].arn}"
    ]

    effect = "Allow"
  }
}
