resource "aws_dynamodb_table" "scaling_lock" {
  name           = "AdoScalingLocks"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "ScalingLock"

  attribute {
    name = "ScalingLock"
    type = "S"
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled = true
  }
}