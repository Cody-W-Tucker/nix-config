#!/bin/sh
set -eu
docker exec postgres pg_dumpall -U postgres > /mnt/backup/backups/langfuse/postgres.sql.in-progress
mv -f /mnt/backup/backups/langfuse/postgres.sql.in-progress /mnt/backup/backups/langfuse/postgres.sql
