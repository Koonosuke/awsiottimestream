output "timestream_database" {
  value = aws_timestreamwrite_database.waterlevel_db.database_name
}

output "timestream_table" {
  value = aws_timestreamwrite_table.distance_table.table_name
}

output "iot_rule_name" {
  value = aws_iot_topic_rule.ingest_waterlevel.name
}
