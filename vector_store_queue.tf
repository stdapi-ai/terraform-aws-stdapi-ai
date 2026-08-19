/*
Durable vector store indexing on Amazon SQS

The queue makes an indexing job outlive the task that accepted it: the work is recorded on the
queue inside the request, and any task of the service picks it up, so a deployment or a scale-in
settles the file as completed instead of failed. It is only useful once the Vector Stores API has
somewhere to index into — the server refuses the setting without a vector bucket — so it follows
that API rather than being created unconditionally.
*/

locals {
  # The Vector Stores API is enabled. Read from the configuration alone, unlike
  # local.s3_vectors_bucket_name, so it can gate the VPC endpoint set at plan time.
  vector_stores_enabled = var.aws_s3_vectors_bucket != null || local.create_s3_vectors_bucket

  # Create the queue only if enabled, no user-provided queue, and something to index
  create_sqs_vector_store_queue = (
    var.aws_sqs_vector_store_queue_create &&
    var.aws_sqs_vector_store_queue_url == null &&
    local.vector_stores_enabled
  )

  # Durable indexing is enabled. Known at plan time, for the same reason as above.
  sqs_vector_store_enabled = var.aws_sqs_vector_store_queue_url != null || local.create_sqs_vector_store_queue

  # Region the queue is reached in. The server reads it from the URL and from nothing else, so a
  # user-provided queue may sit outside the region this module is deployed in.
  sqs_vector_store_queue_region = var.aws_sqs_vector_store_queue_url != null ? (
    split(".", split("/", var.aws_sqs_vector_store_queue_url)[2])[1]
  ) : local.current_region

  # Determine the queue URL to use for the application
  # Priority: user-specified queue > auto-created queue > null (durable indexing disabled)
  sqs_vector_store_queue_url = var.aws_sqs_vector_store_queue_url != null ? var.aws_sqs_vector_store_queue_url : (
    local.create_sqs_vector_store_queue ? aws_sqs_queue.vector_store[0].url : null
  )

  # Queue ARN the task role is granted on. A user-provided URL already carries every part of its
  # ARN: its third path segment is the account ID and its fourth the queue name.
  sqs_vector_store_queue_arn = var.aws_sqs_vector_store_queue_url != null ? format(
    "arn:%s:sqs:%s:%s:%s",
    data.aws_partition.current.partition,
    local.sqs_vector_store_queue_region,
    split("/", var.aws_sqs_vector_store_queue_url)[3],
    split("/", var.aws_sqs_vector_store_queue_url)[4],
    ) : (
    local.create_sqs_vector_store_queue ? aws_sqs_queue.vector_store[0].arn : null
  )

  # KMS key the task role uses through Amazon SQS, for the created queue or a user-provided one
  sqs_vector_store_queue_kms_key_arn = local.create_sqs_vector_store_queue ? module.kms_key.arn : var.aws_sqs_vector_store_queue_kms_key_arn
}

# Dead-letter queue: a job still failing after the redrive policy's deliveries is settled as
# failed by the server and its message kept here instead of being dropped, so what was refused
# stays visible. It is a queue like any other, and carries the same encryption and tags.
resource "aws_sqs_queue" "vector_store_dead_letter" {
  count             = local.create_sqs_vector_store_queue ? 1 : 0
  name              = "${local.name}-vector-store-dlq"
  kms_master_key_id = module.kms_key.id
  # The maximum Amazon SQS allows: a message here is evidence to look at, not work to run.
  message_retention_seconds = 1209600
  tags                      = merge(local.apn_tags, { Name = "${local.name}-vector-store-dlq" })

  depends_on = [module.kms_key.policy_dependency]
}

# Only this deployment's queue may redrive into the dead-letter queue. Left unset, Amazon SQS
# lets every queue of the account use it.
resource "aws_sqs_queue_redrive_allow_policy" "vector_store_dead_letter" {
  count     = local.create_sqs_vector_store_queue ? 1 : 0
  queue_url = aws_sqs_queue.vector_store_dead_letter[0].url

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.vector_store[0].arn]
  })
}

# Standard, never FIFO: the server refuses a FIFO queue, whose content-based deduplication would
# silently drop a legitimate re-attach of the same files, and ordering buys the indexing nothing.
# No queue policy is attached: the task role reaches the queue through its identity policy alone,
# so there is no resource policy that could grant anyone else access.
resource "aws_sqs_queue" "vector_store" {
  count             = local.create_sqs_vector_store_queue ? 1 : 0
  name              = "${local.name}-vector-store"
  kms_master_key_id = module.kms_key.id
  # A job is minutes of work, so retention only matters across an outage, which four days covers.
  # The wait and the visibility timeout are set by each receive rather than by the queue.
  message_retention_seconds = 345600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.vector_store_dead_letter[0].arn
    # The server reads this policy at startup and gives a file exactly this many attempts before
    # settling it as failed; 3 is also what it falls back to when a queue carries no policy.
    maxReceiveCount = 3
  })
  tags = merge(local.apn_tags, { Name = "${local.name}-vector-store" })

  depends_on = [module.kms_key.policy_dependency]
}
