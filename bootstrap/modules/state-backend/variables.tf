variable "bucket_name"{
    description = "Globally unique name for the S3 state bucket"
    type        = string
}

variable "table_name"{
    description = "Name of the DynamoDB table for state locking"
    type        = string
}