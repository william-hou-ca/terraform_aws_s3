s3_buckets = [
  {
    bucket_name = "tf-s3-test"
    acl         = "private"
    tags        = { env = "dev" }
    public_access_block = {
      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true
    }
    static_web_hosting = {
      index = "index.html"
      error = "errorinfo.html"
    }
    cors_rule = [
      {
        allowed_headers = ["*"]
        allowed_methods = ["PUT", "POST"]
        allowed_origins = ["https://s3-website-test1.hashicorp.com"]
        expose_headers  = ["ETag"]
        max_age_seconds = 3001
      },
      {
        allowed_headers = ["*"]
        allowed_methods = ["PUT", "POST"]
        allowed_origins = ["https://s3-website-test2.hashicorp.com"]
        expose_headers  = ["ETag"]
        max_age_seconds = 3002
      },
    ]
    versioning = {
      enabled    = true
      mfa_delete = false
    }
    logging = {
      target_bucket_id = 0
      target_prefix    = "tf-s3-testlog"
    }
    lifecycle_rule = [
      {
        id      = "log"
        enabled = true
        prefix  = "log/"
        tags    = { rule = "log", autoclean = "true" }
        expiration = {
          days = 22
        }
      },
      {
        id      = "tmp"
        enabled = true
        prefix  = "tmp/"
        tags    = { rule = "tmp", autoclean = "true" }
        transition = {
          days          = 30
          storage_class = "STANDARD_IA" # or "ONEZONE_IA"
        }
      }
    ]
  },
]

s3_buckets_logging = [
  {
    bucket_name = "tf-s3-test-log"
    tags = {
      env = "dev"
    used = "logging" }
    public_access_block = {
      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true
    }
  },
]