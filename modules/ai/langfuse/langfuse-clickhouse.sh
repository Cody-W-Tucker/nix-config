#!/bin/sh
set -eu
archive="nas-$(date -u +%Y%m%dT%H%M%SZ)-$$.zip"
container_path="/var/lib/clickhouse/backups/$archive"
trap 'docker exec clickhouse rm -f "$container_path"' EXIT
docker exec clickhouse clickhouse-client --query "BACKUP DATABASE default TO File('$container_path')"
docker cp "clickhouse:$container_path" /mnt/backup/backups/langfuse/clickhouse.zip.in-progress
mv -f /mnt/backup/backups/langfuse/clickhouse.zip.in-progress /mnt/backup/backups/langfuse/clickhouse.zip
