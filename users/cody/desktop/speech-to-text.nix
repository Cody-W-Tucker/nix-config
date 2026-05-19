{
  inputs,
  pkgs,
  hardwareConfig ? { },
  ...
}:

let
  whispAwaySafe = pkgs.writeShellApplication {
    name = "whisp-away-safe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.procps
    ];
    text = ''
      set -eu

      pidfile="/tmp/whisp-away-recording.pid"
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      is_recording_pid() {
        pid="$1"

        [ -n "$pid" ] || return 1
        [ -r "/proc/$pid/cmdline" ] || return 1

        cmdline="$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
        case "$cmdline" in
          *"pw-record --channels 1 --rate 16000 --format s16 --volume 1.5 $runtime_dir/voice-recording-"*.wav*)
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      find_recording_pids() {
        for proc in /proc/[0-9]*; do
          [ -r "$proc/cmdline" ] || continue

          pid="''${proc#/proc/}"
          cmdline="$(tr '\000' ' ' < "$proc/cmdline" 2>/dev/null || true)"

          case "$cmdline" in
            *"pw-record --channels 1 --rate 16000 --format s16 --volume 1.5 $runtime_dir/voice-recording-"*.wav*)
              printf '%s\n' "$pid"
              ;;
          esac
        done
      }

      stop_pid() {
        pid="$1"

        kill -INT "$pid" 2>/dev/null || true
        i=0
        while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do
          sleep 0.05
          i=$((i + 1))
        done

        if kill -0 "$pid" 2>/dev/null; then
          kill -TERM "$pid" 2>/dev/null || true
          i=0
          while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do
            sleep 0.05
            i=$((i + 1))
          done
        fi

        if kill -0 "$pid" 2>/dev/null; then
          kill -KILL "$pid" 2>/dev/null || true
        fi
      }

      cleanup_stale_recording() {
        pid=""
        if [ -f "$pidfile" ]; then
          pid="$(tr -d '[:space:]' < "$pidfile" 2>/dev/null || true)"
        fi

        if is_recording_pid "$pid"; then
          stop_pid "$pid"
        fi

        for orphan_pid in $(find_recording_pids); do
          [ "$orphan_pid" = "$pid" ] && continue
          stop_pid "$orphan_pid"
        done

        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
          rm -f "$pidfile"
        fi

        if [ -f "$pidfile" ] && ! is_recording_pid "$pid"; then
          rm -f "$pidfile"
        fi
      }

      command="''${1:-}"

      case "$command" in
        start)
          cleanup_stale_recording
          ;;
        stop)
          cleanup_stale_recording
          ;;
      esac

      exec whisp-away "$@"
    '';
  };
in

{
  imports = [ inputs.whisp-away.nixosModules.home-manager ];

  services.whisp-away = {
    enable = hardwareConfig.enableWhisp or true;
    defaultModel = "small.en";
    defaultBackend = "whisper-cpp";
    # Use acceleration from hardware config, fallback to CPU for fast builds
    accelerationType = hardwareConfig.whispAcceleration or "cpu";
    useClipboard = false;
    useCrane = false;
  };

  home.packages = [ whispAwaySafe ];
}
