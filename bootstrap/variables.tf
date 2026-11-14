variable "bucket_name" {
    description = "Globally unique S3 bucket name"
    type        = string
    default     = "praneesh-devops-tfstate-sydney-2026"
}

variable "table_name" {
    description = "DynamoDB lock table name"
    type        = string
    default     = "terraform-state-lock"
}