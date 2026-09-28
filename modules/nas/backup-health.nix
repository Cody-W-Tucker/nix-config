{
  config,
  lib,
  pkgs,
  ...
}:

# NAS backup health metrics for Prometheus node-exporter textfile collector.
#
# Covered systemd units (all daily on nas):
#   - restic-backups-nas-files.service (05:00, includes SQLite staged exports)
#   - postgresqlBackup.service (daily, native pg dumps consumed by restic)
#   - langfuse-postgres-backup.service (daily)
#   - langfuse-clickhouse-backup.service (daily)
#
# Metric semantics (scraped via the existing nas node-exporter job `server`):
#   nas_backup_last_run_timestamp_seconds{backup="<unit>"}     — unixtime of most recent run, any outcome. Always written.
#   nas_backup_last_success_timestamp_seconds{backup="<unit>"} — unixtime of most recent SUCCESS. Absent until the
#     first success; preserved across later failures (parsed back from the previous .prom file).
#   nas_backup_status{backup="<unit>"}                         — 1 if SERVICE_RESULT=success on the most recent run, else 0.
#   nas_backup_duration_seconds{backup="<unit>"}                — wall-clock seconds between ExecStartPre timestamp and
#     ExecStopPost report. Absent when the start stamp is unavailable (e.g. manual `systemctl start` races or /run loss).
#
# Freshness / alerting guidance:
#   - A skipped timer (ConditionPathIsMountPoint unmet, Requires dep failed to start, timer disabled) does NOT write a
#     fresh file, so staleness is the skip signal. Alert when `time() - nas_backup_last_run_timestamp_seconds > 26*3600`
#     for any expected backup="<unit>" (daily + catch-up margin), and when `nas_backup_status != 1`.
#   - A missing nas_backup_last_success_timestamp_seconds series means "never succeeded since exporter state was
#     (re)created" — page, do not assume success. A stale-but-present success timestamp after a recent failed run
#     means "last success was at <timestamp>, latest run failed" — the run metric moves, the success metric does not.
#   - On-call: 1) `systemctl status <unit>` + `journalctl -u <unit>` for the failure, 2) check mounts under
#     /mnt/backup/backups (conditions skip silently), 3) verify /var/lib/node-exporter-textfile/nas_backup_<unit>.prom
#     mtime/content matches the journal, 4) re-run with `systemctl start <unit>` and confirm fresh timestamps.
#
# Implementation notes:
#   - ExecStopPost runs on both success and failure and observes $SERVICE_RESULT; ExecStartPre stamps /run for duration.
#     The "+" prefix forces root so the postgres-owned postgresqlBackup unit can still write the root-owned textfile dir.
#     StopPost uses "-+" so a reporting failure (full disk, lost /run) is logged but never flips a backup to failed.
#   - Writes are atomic (mktemp in the same dir + chmod 0644 + rename) so the collector never reads a partial file.

let
  textfileDir = "/var/lib/node-exporter-textfile";
  runDir = "/run/backup-health";

  reporter = pkgs.writeShellScript "nas-backup-health-report" ''
    set -eu
    job="$1"
    result="''${SERVICE_RESULT:-unknown}"
    now="$(${pkgs.coreutils}/bin/date +%s)"
    outdir="${textfileDir}"
    rundir="${runDir}"
    ${pkgs.coreutils}/bin/mkdir -p "$outdir" "$rundir"
    start_file="$rundir/$job.start"
    duration=""
    if [ -f "$start_file" ]; then
      start="$(${pkgs.coreutils}/bin/cat "$start_file" 2>/dev/null || true)"
      case "$start" in
        ""|*[!0-9]*) ;;
        *) duration=$((now - start)); if [ "$duration" -lt 0 ]; then duration=""; fi ;;
      esac
      ${pkgs.coreutils}/bin/rm -f "$start_file"
    fi
    if [ "$result" = "success" ]; then status=1; else status=0; fi
    dest="$outdir/nas_backup_$job.prom"
    prev_success=""
    if [ -f "$dest" ]; then
      prev_success="$(${pkgs.gnugrep}/bin/grep -F "nas_backup_last_success_timestamp_seconds{backup=\"$job\"}" "$dest" 2>/dev/null | ${pkgs.coreutils}/bin/cut -d ' ' -f2 || true)"
      case "$prev_success" in
        ""|*[!0-9]*) prev_success="" ;;
      esac
    fi
    if [ "$status" -eq 1 ]; then success="$now"; else success="$prev_success"; fi
    tmp="$(${pkgs.coreutils}/bin/mktemp "$outdir/.nas_backup_$job.prom.XXXXXX")"
    {
      printf '# HELP nas_backup_last_run_timestamp_seconds Unix time of most recent backup run (any outcome).\n'
      printf '# TYPE nas_backup_last_run_timestamp_seconds gauge\n'
      printf 'nas_backup_last_run_timestamp_seconds{backup="%s"} %s\n' "$job" "$now"
      if [ -n "$success" ]; then
        printf '# HELP nas_backup_last_success_timestamp_seconds Unix time of most recent successful backup run. Absent until first success; preserved across failures.\n'
        printf '# TYPE nas_backup_last_success_timestamp_seconds gauge\n'
        printf 'nas_backup_last_success_timestamp_seconds{backup="%s"} %s\n' "$job" "$success"
      fi
      printf '# HELP nas_backup_status 1 if the most recent run succeeded (SERVICE_RESULT=success), 0 otherwise.\n'
      printf '# TYPE nas_backup_status gauge\n'
      printf 'nas_backup_status{backup="%s"} %s\n' "$job" "$status"
      if [ -n "$duration" ]; then
        printf '# HELP nas_backup_duration_seconds Duration of the most recent run in seconds (start-file based; absent if unavailable).\n'
        printf '# TYPE nas_backup_duration_seconds gauge\n'
        printf 'nas_backup_duration_seconds{backup="%s"} %s\n' "$job" "$duration"
      fi
    } > "$tmp"
    ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
    ${pkgs.coreutils}/bin/mv -f "$tmp" "$dest"
  '';

  mkHealthHooks = job: {
    # mkBefore: stamp the start time before any other ExecStartPre (e.g. the
    # restic backupPrepareCommand wrapper) so duration covers the whole run.
    ExecStartPre = lib.mkBefore [
      "+${pkgs.coreutils}/bin/mkdir -p ${runDir} ${textfileDir}"
      "+${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/date +%%s > ${runDir}/${job}.start'"
    ];
    # "-+": run as root (+) and never fail the backup unit if reporting fails (-).
    ExecStopPost = [ "-+${reporter} ${job}" ];
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 root root -"
    "d ${runDir} 0755 root root -"
  ];

  # Merge with monitoring.nix: enabledCollectors ["systemd"] ++ ["textfile"],
  # and expose the explicit textfile directory to the nas node exporter (job `server`).
  services.prometheus.exporters.node.enabledCollectors = [ "textfile" ];
  services.prometheus.exporters.node.extraFlags = [
    "--collector.textfile.directory=${textfileDir}"
  ];

  systemd.services."restic-backups-nas-files".serviceConfig =
    mkHealthHooks "restic-backups-nas-files";
  systemd.services."postgresqlBackup".serviceConfig = mkHealthHooks "postgresqlBackup";
  systemd.services."langfuse-postgres-backup".serviceConfig =
    mkHealthHooks "langfuse-postgres-backup";
  systemd.services."langfuse-clickhouse-backup".serviceConfig =
    mkHealthHooks "langfuse-clickhouse-backup";
}
