variable "s3_buckets" {
  type = list(any)
  description = "create s3_buckets in according to this variable"
}

variable "cors_rule" {
 type = any
 default = [
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