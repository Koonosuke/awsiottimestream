terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # ★必要に応じて変更
}

# -----------------------
# Timestream Database
# -----------------------
resource "aws_timestreamwrite_database" "waterlevel_db" {
  database_name = "iot_waterlevel_db"
}

# -----------------------
# Timestream Table
# -----------------------
resource "aws_timestreamwrite_table" "distance_table" {
  database_name = aws_timestreamwrite_database.waterlevel_db.database_name
  table_name    = "distance_table"
}

# -----------------------
# IoT Role for Rule
# -----------------------
resource "aws_iam_role" "iot_rule_role" {
  name = "iot_rule_waterlevel_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_rule_policy" {
  name = "iot_rule_waterlevel_policy"
  role = aws_iam_role.iot_rule_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "timestream:WriteRecords",
          "timestream:DescribeEndpoints"
        ]
        Resource = [
          aws_timestreamwrite_table.distance_table.arn,
          aws_timestreamwrite_database.waterlevel_db.arn
        ]
      }
    ]
  })
}

# -----------------------
# IoT Topic Rule
# -----------------------
resource "aws_iot_topic_rule" "ingest_waterlevel" {
  name        = "ingest_waterlevel"
  description = "Rule to insert waterlevel data into Timestream"
  enabled     = true
  sql         = <<EOT
SELECT 
  CAST(payloads.distance AS DOUBLE) AS distance,
  payloads.fieldId AS fieldId,
  topic(2) AS deviceId,
  timestamp
FROM 'waterlevel/+'
EOT
  sql_version = "2016-03-23"

  timestream {
    database_name = aws_timestreamwrite_database.waterlevel_db.database_name
    table_name    = aws_timestreamwrite_table.distance_table.table_name
    role_arn      = aws_iam_role.iot_rule_role.arn

    dimension {
      name  = "deviceId"
      value = "${topic(2)}"
    }

    dimension {
      name  = "fieldId"
      value = "${payloads.fieldId}"
    }
  }
}
