{
  config,
  lib,
  pkgs,
  ...
}:

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
    # mkBefore so duration covers the whole run; + runs as root; %%s avoids systemd specifier expansion.
    ExecStartPre = lib.mkBefore [
      "+${pkgs.coreutils}/bin/mkdir -p ${runDir} ${textfileDir}"
      "+${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/date +%%s > ${runDir}/${job}.start'"
    ];
    # -+: run as root (+) without failing the backup unit on reporting errors (-).
    ExecStopPost = [ "-+${reporter} ${job}" ];
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 root root -"
    "d ${runDir} 0755 root root -"
  ];

  services.prometheus.exporters.node.enabledCollectors = [ "textfile" ];
  services.prometheus.exporters.node.extraFlags = [
    "--collector.textfile.directory=${textfileDir}"
  ];

  # Retired Restic textfile after migration to prometheus-restic-exporter,
  # plus retired ZFS snapshot inventory after migration to zfs_exporter.
  # Targeted to these single paths only; safe to run on every activation.
  system.activationScripts.cleanup-retired-restic-prom.text = ''
    ${pkgs.coreutils}/bin/rm -f ${textfileDir}/nas_backup_restic-backups-nas-files.prom ${textfileDir}/nas_zfs_snapshots.prom
  '';

  systemd.services."postgresqlBackup".serviceConfig = mkHealthHooks "postgresqlBackup";
  systemd.services."langfuse-postgres-backup".serviceConfig =
    mkHealthHooks "langfuse-postgres-backup";
  systemd.services."langfuse-clickhouse-backup".serviceConfig =
    mkHealthHooks "langfuse-clickhouse-backup";
}
