variable "s3_buckets" {
  type        = list(any)
  description = "create s3_buckets in according to this variable"
}

variable "s3_buckets_logging" {
  type        = list(any)
  description = "working as logging buckets for buckets in the variable s3_buckets"
}

variable "s3_replication_dst_region" {
  type        = string
  description = "define which region buckets are replicated to"
}

variable "s3_buckets_destination" {
  type        = list(any)
  description = "replication destination buckets"
}

variable "s3_buckets_force_destroy" {
  type        = string
  description = "force destroy s3 buckets when they are not empty. Pay attention to this parameter!!!!!!!"
  default     = false
}