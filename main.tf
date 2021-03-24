provider "aws" {
  region = "ca-central-1"
}

provider "aws" {
  alias  = "rep_dst"
  region = var.s3_replication_dst_region
}
####################################################################################
#
# create s3 buckets in accroding to the variable var.s3_buckets
#
####################################################################################

resource "aws_s3_bucket" "this" {
  count = length(var.s3_buckets)


  bucket_prefix = "${var.s3_buckets[count.index].bucket_name}-"
  acl           = var.s3_buckets[count.index].acl

  force_destroy = var.s3_buckets_force_destroy

  tags = merge(var.s3_buckets[count.index].tags,
    {
      Name = var.s3_buckets[count.index].bucket_name
    }
  )

  # S3 Static Website Hosting function
  dynamic "website" {
    for_each = contains(keys(var.s3_buckets[count.index]), "static_web_hosting") ? [var.s3_buckets[count.index].static_web_hosting] : []

    content {
      index_document = lookup(website.value, "index", "index.html")
      error_document = lookup(website.value, "error", "error.html")

      routing_rules = <<-EOF
        [{
            "Condition": {
                "KeyPrefixEquals": "docs/"
            },
            "Redirect": {
                "ReplaceKeyPrefixWith": "documents/"
            }
        }]
        EOF
    }
  }

  # Using CORS
  dynamic "cors_rule" {
    # if you don't use jsondecode and jsonencode, terraform will always show the error: Inconsistent conditional result types
    # this is a bug of terraform not yet resolved
    for_each = jsondecode(contains(keys(var.s3_buckets[count.index]), "cors_rule") ? jsonencode(var.s3_buckets[count.index].cors_rule) : jsonencode([{}]))

    content {
      allowed_headers = lookup(cors_rule.value, "allowed_headers", ["*"])
      allowed_methods = lookup(cors_rule.value, "allowed_methods", ["PUT", "POST"])
      allowed_origins = lookup(cors_rule.value, "allowed_origins", [])
      expose_headers  = lookup(cors_rule.value, "expose_headers", ["ETag"])
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", 3000)
    }
  }

  # Using versioning
  dynamic "versioning" {
    for_each = contains(keys(var.s3_buckets[count.index]), "versioning") ? [var.s3_buckets[count.index].versioning] : []

    content {
      enabled    = lookup(versioning.value, "enabled", false)
      mfa_delete = lookup(versioning.value, "mfa_delete", false)
    }
  }

  # Enable Logging
  dynamic "logging" {
    for_each = contains(keys(var.s3_buckets[count.index]), "logging") ? [var.s3_buckets[count.index].logging] : []

    content {
      target_bucket = contains(keys(logging.value), "target_bucket_id") ? aws_s3_bucket.logging[lookup(logging.value, "target_bucket_id")].id : null
      target_prefix = contains(keys(logging.value), "target_prefix") ? lookup(logging.value, "target_prefix", null) : var.s3_buckets[count.index].bucket_name
    }
  }

  # lifecycle_rule 
  dynamic "lifecycle_rule" {
    for_each = jsondecode(contains(keys(var.s3_buckets[count.index]), "lifecycle_rule") ? jsonencode(var.s3_buckets[count.index].lifecycle_rule) : jsonencode([{}]))

    content {
      id      = lookup(lifecycle_rule.value, "id", "lr-id-${count.index}")
      enabled = lookup(lifecycle_rule.value, "enabled", false)
      prefix  = lookup(lifecycle_rule.value, "prefix", null)


      dynamic "expiration" {
        for_each = contains(keys(lifecycle_rule.value), "expiration") ? [lifecycle_rule.value.expiration] : []

        content {
          days = lookup(expiration.value, "days", 0)
        }
      }

      dynamic "transition" {
        for_each = contains(keys(lifecycle_rule.value), "transition") ? [lifecycle_rule.value.transition] : []

        content {
          days          = lookup(transition.value, "days", 0)
          storage_class = lookup(transition.value, "storage_class", "GLACIER")
        }
      }
    }
  }

  # Using replication configuration
  dynamic "replication_configuration" {
    for_each = contains(keys(var.s3_buckets[count.index]), "replication_configuration") ? [var.s3_buckets[count.index].replication_configuration] : []

    content {
      role = aws_iam_role.replication[replication_configuration.value.dst_bucket_id].arn

      dynamic "rules" {
        for_each = jsondecode(contains(keys(replication_configuration.value), "rules") ? jsonencode(replication_configuration.value.rules) : jsonencode([{}]))

        content {
          id     = rules.value.id
          prefix = rules.value.prefix
          status = rules.value.status

          destination {
            bucket        = aws_s3_bucket.destination[replication_configuration.value.dst_bucket_id].arn
            storage_class = rules.value.storage_class
          }
        }
      }
    }
  }

  # Enable Default Server Side Encryption
  dynamic "server_side_encryption_configuration" {
    for_each = contains(keys(var.s3_buckets[count.index]), "server_side_encryption_configuration") ? [var.s3_buckets[count.index].server_side_encryption_configuration] : []

    content {
      rule {
        apply_server_side_encryption_by_default {
          #kms_master_key_id = aws_kms_key.mykey.arn
          sse_algorithm = "aws:kms"
        }
      }
    }
  }
}


####################################################################################
#
# create s3 buckets' logging bucket
#
####################################################################################

resource "aws_s3_bucket" "logging" {
  count = length(var.s3_buckets_logging)


  bucket_prefix = "${var.s3_buckets_logging[count.index].bucket_name}-"
  force_destroy = var.s3_buckets_force_destroy

  grant {
    type        = "Group"
    permissions = ["READ_ACP", "WRITE"]
    uri         = "http://acs.amazonaws.com/groups/s3/LogDelivery"
  }

  grant {
    type        = "CanonicalUser"
    id          = local.aws_cano_id #if you use directly data.aws_canonical_user_id.current.id, this bucket will be always changed in-place
    permissions = ["FULL_CONTROL"]
  }

  tags = merge(var.s3_buckets_logging[count.index].tags,
    {
      Name = var.s3_buckets_logging[count.index].bucket_name
    }
  )
}

data "aws_canonical_user_id" "current" {}
locals {
  aws_cano_id = data.aws_canonical_user_id.current.id
}
####################################################################################
#
# create s3 buckets' public access block rules
#
####################################################################################

resource "aws_s3_bucket_public_access_block" "this" {
  count = length(var.s3_buckets)

  bucket = aws_s3_bucket.this[count.index].id

  block_public_acls       = contains(keys(var.s3_buckets[count.index]), "public_access_block") ? lookup(var.s3_buckets[count.index].public_access_block, "block_public_acls", true) : true
  block_public_policy     = contains(keys(var.s3_buckets[count.index]), "public_access_block") ? lookup(var.s3_buckets[count.index].public_access_block, "block_public_policy", true) : true
  ignore_public_acls      = contains(keys(var.s3_buckets[count.index]), "public_access_block") ? lookup(var.s3_buckets[count.index].public_access_block, "ignore_public_acls", true) : true
  restrict_public_buckets = contains(keys(var.s3_buckets[count.index]), "public_access_block") ? lookup(var.s3_buckets[count.index].public_access_block, "restrict_public_buckets", true) : true
}

resource "aws_s3_bucket_public_access_block" "logging" {
  count = length(var.s3_buckets_logging)

  bucket = aws_s3_bucket.logging[count.index].id

  block_public_acls       = contains(keys(var.s3_buckets_logging[count.index]), "public_access_block") ? lookup(var.s3_buckets_logging[count.index].public_access_block, "block_public_acls", true) : true
  block_public_policy     = contains(keys(var.s3_buckets_logging[count.index]), "public_access_block") ? lookup(var.s3_buckets_logging[count.index].public_access_block, "block_public_policy", true) : true
  ignore_public_acls      = contains(keys(var.s3_buckets_logging[count.index]), "public_access_block") ? lookup(var.s3_buckets_logging[count.index].public_access_block, "ignore_public_acls", true) : true
  restrict_public_buckets = contains(keys(var.s3_buckets_logging[count.index]), "public_access_block") ? lookup(var.s3_buckets_logging[count.index].public_access_block, "restrict_public_buckets", true) : true

}

####################################################################################
#
# create s3 replication destination buckets
#
####################################################################################

resource "aws_iam_role" "replication" {
  count = length(var.s3_buckets_destination)

  name_prefix = "tf-iam-role-replication-"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "replication" {
  count = length(var.s3_buckets_destination)

  name_prefix = "tf-iam-role-policy-replication-"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.this[var.s3_buckets_destination[count.index].source_buckets_id].arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.this[var.s3_buckets_destination[count.index].source_buckets_id].arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.destination[count.index].arn}/*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "replication" {
  count = length(var.s3_buckets_destination)

  role       = aws_iam_role.replication[count.index].name
  policy_arn = aws_iam_policy.replication[count.index].arn
}

resource "aws_s3_bucket" "destination" {
  provider = aws.rep_dst
  count    = length(var.s3_buckets_destination)

  bucket_prefix = "${var.s3_buckets_destination[count.index].bucket_name}-"
  force_destroy = var.s3_buckets_force_destroy

  versioning {
    enabled = true
  }
}
