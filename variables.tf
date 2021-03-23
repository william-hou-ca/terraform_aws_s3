variable "s3_buckets" {
  type        = list(any)
  description = "create s3_buckets in according to this variable"
}

variable "s3_buckets_logging" {
  type        = list(any)
  description = "working as logging buckets for buckets in the variable s3_buckets"
}