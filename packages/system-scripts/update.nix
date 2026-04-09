{ pkgs }:

pkgs.writeShellScriptBin "update" ''
  set -euo pipefail

  host="$(hostname -s)"
  otel_cli="${pkgs.otel-cli}/bin/otel-cli"
  trace_endpoint="''${CODYOS_OTEL_TRACES_ENDPOINT:-}"

  if [ -z "$trace_endpoint" ]; then
    if [ "$host" = "server" ]; then
      trace_endpoint="http://127.0.0.1:4318/v1/traces"
    else
      trace_endpoint="http://server:4318/v1/traces"
    fi
  fi

  trace_enabled=1
  if [ "''${CODYOS_TRACE_DISABLE:-0}" = "1" ]; then
    trace_enabled=0
  fi

  otel_base_args=(
    --protocol http/protobuf
    --traces-endpoint "$trace_endpoint"
    --timeout 2s
  )

  trace_exec() {
    local span_name="$1"
    shift

    if [ "$trace_enabled" -eq 1 ]; then
      "$otel_cli" exec "''${otel_base_args[@]}" \
        --service codyos-update \
        --name "$span_name" \
        --attrs "host=$host" \
        -- "$@"
    else
      "$@"
    fi
  }

  emit_span() {
    local span_name="$1"
    local attrs="$2"
    local status_code="''${3:-ok}"

    if [ "$trace_enabled" -eq 1 ] && [ -n "''${TRACEPARENT:-}" ]; then
      "$otel_cli" span "''${otel_base_args[@]}" \
        --service codyos-update \
        --name "$span_name" \
        --status-code "$status_code" \
        --attrs "$attrs"
    fi
  }

  count_failed_units() {
    systemctl list-units --failed --no-legend --plain | wc -l | tr -d ' '
  }

  count_recent_errors() {
    journalctl -b -p err --since "-15 min" --no-pager -q | wc -l | tr -d ' '
  }

  count_recent_coredumps() {
    journalctl -b -p crit --since "-15 min" --no-pager -q | grep -i "dumped core\|segfault\|sigsegv\|sigabrt" | wc -l | tr -d ' '
  }

  if [ "$trace_enabled" -eq 1 ] && [ -z "''${TRACEPARENT:-}" ] && [ "''${1:-}" != "--trace-inner" ]; then
    # otel-cli 0.4.5 crashes when exec is given a script directly.
    exec "$otel_cli" exec "''${otel_base_args[@]}" \
      --service codyos-update \
      --name nixos.rebuild \
      --attrs "host=$host,repo=/etc/nixos" \
      -- ${pkgs.bash}/bin/bash "$0" --trace-inner "$@"
  fi

  if [ "''${1:-}" = "--trace-inner" ]; then
    shift
  fi

  cd /etc/nixos

  failed_units_before="$(count_failed_units)"
  error_logs_before="$(count_recent_errors)"
  coredumps_before="$(count_recent_coredumps)"
  emit_span \
    "system.health.baseline" \
    "host=$host,failed_units=$failed_units_before,error_logs_15m=$error_logs_before,coredumps_15m=$coredumps_before"

  trace_exec nix.format nix fmt

  # Check for unimported .nix files
  trace_exec nix.check_imports check-imports

  trace_exec git.stage git add .

  if [ -z "''${1:-}" ]; then
    echo "Enter commit message:"
    read -r commit_message
    commit_message=''${commit_message:-"Update NixOS configuration"}
  else
    commit_message="$1"
  fi

  trace_exec git.commit git commit -m "$commit_message"

  current_rev="$(git rev-parse --short HEAD)"
  emit_span "git.commit.summary" "host=$host,git_sha=$current_rev"

  trace_exec nixos.switch sudo nixos-rebuild switch

  failed_units_after="$(count_failed_units)"
  error_logs_after="$(count_recent_errors)"
  coredumps_after="$(count_recent_coredumps)"
  failed_units_delta=$((failed_units_after - failed_units_before))
  error_logs_delta=$((error_logs_after - error_logs_before))
  coredumps_delta=$((coredumps_after - coredumps_before))

  health_status="ok"
  if [ "$failed_units_delta" -gt 0 ] || [ "$error_logs_delta" -gt 0 ] || [ "$coredumps_delta" -gt 0 ]; then
    health_status="error"
  fi

  emit_span \
    "nixos.switch.health" \
    "host=$host,failed_units_before=$failed_units_before,failed_units_after=$failed_units_after,failed_units_delta=$failed_units_delta,error_logs_15m_before=$error_logs_before,error_logs_15m_after=$error_logs_after,error_logs_delta=$error_logs_delta,coredumps_15m_before=$coredumps_before,coredumps_15m_after=$coredumps_after,coredumps_delta=$coredumps_delta" \
    "$health_status"

  trace_exec git.push git push
''
