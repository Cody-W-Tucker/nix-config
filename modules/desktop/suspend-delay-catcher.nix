{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.suspend-delay-catcher;

  # systemd-sleep hook: runs with "pre"/"post" around every system suspend.
  # Best-effort observation only; never changes sleep behavior and every
  # diagnostic command is hard-bounded by timeout so suspend is not delayed.
  #
  # MESSAGE is a fixed-shape, reliably-valid JSON object built only from
  # system-generated values (timestamps, token, phase). All richer evidence
  # travels as dedicated journald fields (FIELD=VALUE via logger --journald),
  # so even a malformed detail can never invalidate the MESSAGE JSON, and no
  # jq dependency is needed. Evidence is redacted: comm names/counts only —
  # never process cmdlines or environment.
  hookScript = pkgs.writeShellScript "suspend-delay-catcher-hook" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.procps
        pkgs.util-linux
      ]
    }:/run/current-system/sw/bin"

    systemd_bin="${pkgs.systemd}/bin"
    state_dir="/var/lib/suspend-delay-catcher"
    retention_days="${toString cfg.retentionDays}"

    phase="''${1:-unknown}"

    # Hard wall-clock bound for any diagnostic command (best-effort guard
    # against delaying suspend/resume observation significantly).
    bound() { timeout 5 "$@"; }

    mkdir -p "$state_dir" 2>/dev/null
    chmod 700 "$state_dir" 2>/dev/null

    # Structured journal fields via logger --journald (FIELD=VALUE lines).
    # The MESSAGE field itself is the only JSON, and it is fixed-shape.
    emit() {
      {
        echo "SYSLOG_IDENTIFIER=suspend-delay-catcher"
        echo "SCHEMA=suspend-delay-catcher/v1"
        echo "DETECTION=best-effort"
        echo "LIMITATIONS=observer runs from systemd-sleep hook; process evidence is comm-name summary only (no cmdline/env); journal excerpts are best-effort and bounded to this attempt's pre..post window; pre/post pairing may fail (orphan post) and duration is then reported as -1"
        echo "PHASE=$phase"
        for field in "$@"; do
          echo "$field"
        done
      } | logger --journald 2>/dev/null
    }

    # Make a value safe to embed inside a double-quoted JSON string:
    # drop everything that could break out of the string.
    scrub() { tr -d '"\\' | tr '\n' ' '; }

    # Fixed-shape, reliably-valid JSON MESSAGE: every value is either a
    # scrubbed system timestamp, a digits-only token, or a constant.
    simple_message() {
      printf '{"schema":"suspend-delay-catcher/v1","event":"%s","phase":"%s","token":"%s","ts":"%s","detection":"best-effort"}' \
        "$1" "$phase" "$token" "$now_iso"
    }

    # Unique token per suspend attempt, nanosecond precision; the leading
    # 10 digits are the epoch-seconds timestamp of the attempt.
    token="$(date +%s%N)"
    case "+$token" in
      *[!0-9]*) token="$(date +%s)000000000" ;;
    esac
    pre_epoch="''${token%?????????}"
    now_epoch="$(date +%s)"
    now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    if [ "$phase" = pre ]; then
      inhibitors="$("$systemd_bin/systemd-inhibit" --list --no-legend 2>/dev/null | scrub | head -c 1000)"
      inhibitor_count="$("$systemd_bin/systemd-inhibit" --list --no-legend 2>/dev/null | wc -l)"
      proc_count="$(cat /sys/fs/cgroup/user.slice/cgroup.procs 2>/dev/null | wc -w)"
      # Bounded, redacted process summary: comm names + counts only (no cmdline args, no env).
      proc_summary="$(cat /sys/fs/cgroup/user.slice/cgroup.procs 2>/dev/null | head -n 300 | while read -r p; do bound ps -o comm= -p "$p" 2>/dev/null; done | sort | uniq -c | sort -rn | head -n 40 | scrub | head -c 800)"
      acpi_wakeup="$(cat /proc/acpi/wakeup 2>/dev/null | scrub | head -c 1000)"

      # Pre evidence slot keyed by the unique attempt token.
      {
        printf '%s\n' "$now_iso"
        printf '%s\n' "$inhibitor_count"
        printf '%s\n' "$proc_count"
        printf '%s\n' "$proc_summary"
      } > "$state_dir/pre-$token"
      printf '%s\n' "$token" > "$state_dir/last-pre"

      emit \
        "PAIR_TOKEN=$token" \
        "INHIBITOR_COUNT=$inhibitor_count" \
        "USER_PROCS=$proc_count" \
        "INHIBITORS=$inhibitors" \
        "USER_PROC_SUMMARY=$proc_summary" \
        "ACPI_WAKEUP=$acpi_wakeup" \
        "MESSAGE=$(simple_message suspend-pre)"

    elif [ "$phase" = post ]; then
      # Pair with the pre attempt via its unique token slot; remove the slot
      # immediately so no later post can consume a stale pre.
      paired_token="$(head -n 1 "$state_dir/last-pre" 2>/dev/null)"
      rm -f "$state_dir/last-pre"
      if [ -n "$paired_token" ]; then
        token="$paired_token"
        pre_epoch="''${token%?????????}"
        pre_iso="$(sed -n 1p "$state_dir/pre-$token" 2>/dev/null || echo unknown)"
        pre_inhibitor_count="$(sed -n 2p "$state_dir/pre-$token" 2>/dev/null || echo unknown)"
        pre_proc_count="$(sed -n 3p "$state_dir/pre-$token" 2>/dev/null || echo unknown)"
        pre_summary="$(sed -n 4p "$state_dir/pre-$token" 2>/dev/null | head -c 400)"
        paired="true"
        duration=$((now_epoch - pre_epoch))
      else
        paired="false"
        pre_iso="unknown"
        pre_inhibitor_count="unknown"
        pre_proc_count="unknown"
        pre_summary="unknown"
        duration=-1
      fi

      # Diagnose the 60s freeze timeout: search the journal strictly bounded
      # to this attempt's window [pre_epoch, now_epoch]; no whole-boot scan.
      freeze_errors="$("$systemd_bin/journalctl" -q -b --since "@$pre_epoch" --until "@$now_epoch" -n 300 --no-pager 2>/dev/null | grep -iE "failed to freeze|freez[^ ]* timed out|timed out[^|]*freez" | scrub | head -c 1200)"
      suspend_unit_log="$("$systemd_bin/journalctl" -q -b -u systemd-suspend.service --since "@$pre_epoch" --until "@$now_epoch" -n 60 --no-pager 2>/dev/null | tail -n 20 | scrub | head -c 1200)"
      user_units="$("$systemd_bin/systemctl" list-units --no-legend --plain --no-pager "user@*.service" "session-*.scope" 2>/dev/null | head -n 20 | scrub | head -c 800)"

      if [ -n "$freeze_errors" ]; then
        incident="true"
        printf '{"event":"suspend-incident","ts":"%s","token":"%s","pre_ts":"%s","duration_s":%s,"freeze_errors":"%s","suspend_unit_log":"%s"}\n' \
          "$now_iso" "$token" "$pre_iso" "$duration" "$freeze_errors" "$suspend_unit_log" \
          >> "$state_dir/incidents.log"
        # Keep the incident log bounded (last 20 KiB).
        tail -c 20000 "$state_dir/incidents.log" > "$state_dir/incidents.log.tmp"
        mv "$state_dir/incidents.log.tmp" "$state_dir/incidents.log"
      else
        incident="false"
      fi

      emit \
        "PAIR_TOKEN=$token" \
        "PAIRED=$paired" \
        "PRE_TS=$pre_iso" \
        "PRE_INHIBITOR_COUNT=$pre_inhibitor_count" \
        "PRE_USER_PROCS=$pre_proc_count" \
        "DURATION_S=$duration" \
        "FREEZE_FAILED=$incident" \
        "FREEZE_ERRORS=$freeze_errors" \
        "SUSPEND_UNIT_LOG=$suspend_unit_log" \
        "USER_UNITS_AT_POST=$user_units" \
        "USER_PROC_SUMMARY_AT_PRE=$pre_summary" \
        "MESSAGE=$(simple_message suspend-post)"

      # Retention: delete attempt-slot files older than retention_days.
      bound find "$state_dir" -type f -name 'pre-*' -mtime "+$retention_days" -delete 2>/dev/null
    fi
  '';
in
{
  options.services.suspend-delay-catcher = {
    enable = lib.mkEnableOption "system-level suspend incident catcher that logs pre/post-suspend metadata and diagnoses user.slice freeze timeouts";

    retentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = ''
        Days to keep bounded snapshot files under /var/lib/suspend-delay-catcher.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Observes every suspend attempt at the systemd-sleep level, independent
    # of Hypridle/Lua.
    environment.etc."systemd/system-sleep/suspend-delay-catcher".source = hookScript;

    systemd.tmpfiles.settings."30-suspend-delay-catcher"."/var/lib/suspend-delay-catcher".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };
}
