s3_buckets = [
  {
    bucket_name = "tf-s3-test"
    acl = "private"
    tags = { env = "dev" }
    public_access_block = {
      ignore_public_acls = false
    }
    static_web_hosting = {
      error = "errorinfo.index"
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
          allowed_origins = ["https://s3-website-test2.hashicorp.com"]
          max_age_seconds = 3002
      }
    ] 
  }
]