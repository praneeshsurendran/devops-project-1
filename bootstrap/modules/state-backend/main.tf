# 1. Create the S3 Bucket
resource "aws_s3_bucket" "terraform_state" {
    bucket = var.bucket_name

    # Prevents accidental deletion of your state bucket
    lifecycle {
        prevent_destroy = true
    }
}

# 2. Enable Versioning (Allows you to recover corrupted or deleted state files)
resource "aws_s3_bucket_versioning" "enabled" {
    bucket = aws_s3_bucket.terraform_state.id
    versioning_configuration {
        status = "Enabled"
    }
}

# 3. Enable Server-Side Encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
    bucket = aws_s3_bucket.terraform_state.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

# 4. Block all public access to the state file
resource "aws_s3_bucket_public_access_block" "public_access" {
    bucket                  = aws_s3_bucket.terraform_state.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# 5. Create the DynamoDB Locking Table
resource "aws_dynamodb_table" "terraform_locks" {
    name         = var.table_name
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "LockID"

    attribute {
        name = "LockID"
        type = "S"
    }
}