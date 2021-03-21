provider "aws" {
  region = "ca-central-1"
}

####################################################################################
#
# create s3 buckets in accroding to the variable var.s3_buckets
#
####################################################################################

resource "aws_s3_bucket" "this" {
  count = length(var.s3_buckets)


  bucket_prefix  = "${var.s3_buckets[count.index].bucket_name}-"
  acl    = var.s3_buckets[count.index].acl

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
    for_each = contains(keys(var.s3_buckets[count.index]), "cors_rule") ? var.cors_rule : []

    content {
      allowed_headers = lookup(cors_rule.value, "allowed_headers", ["*"])
      allowed_methods = lookup(cors_rule.value, "allowed_methods", ["PUT", "POST"])
      allowed_origins = lookup(cors_rule.value, "allowed_origins", [])
      expose_headers  = lookup(cors_rule.value, "expose_headers", ["ETag"])
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", 3000)
    }
  }

}

####################################################################################
#
# create s3 buckets' public access block rules
#
####################################################################################

resource "aws_s3_bucket_public_access_block" "this" {
  count = length(var.s3_buckets)


  bucket = aws_s3_bucket.this[count.index].id

  block_public_acls   = contains(keys(var.s3_buckets[count.index]), "public_access_block") ? lookup(var.s3_buckets[count.index].public_access_block, "block_public_acls", true ) : true
  block_public_policy = contains(keys(var.s3_buckets[count.index]), "public_access_block") ? lookup(var.s3_buckets[count.index].public_access_block, "block_public_policy", true ) : true
  ignore_public_acls = contains(keys(var.s3_buckets[count.index]), "public_access_block") ? lookup(var.s3_buckets[count.index].public_access_block, "ignore_public_acls", true ) : true
  restrict_public_buckets = contains(keys(var.s3_buckets[count.index]), "public_access_block") ? lookup(var.s3_buckets[count.index].public_access_block, "restrict_public_buckets", true ) : true
}