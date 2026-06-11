{
  pkgs,
  hardwareConfig ? { },
  ...
}:

let
  llamaDictate = pkgs.writeShellApplication {
    name = "llama-dictate";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.libnotify
      pkgs.pipewire
      pkgs.wtype
    ];
    text = ''
      set -eu

      pidfile="/tmp/llama-dictate-recording.pid"
      pathfile="/tmp/llama-dictate-recording.path"
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      api_url="http://127.0.0.1:8081/v1/audio/transcriptions"
      warmup_url="http://127.0.0.1:8081/upstream/whisper-medium/health"
      model="whisper-medium"

      warm_model() {
        # Ask llama-swap to bring up the STT backend without sending fake audio.
        ${pkgs.curl}/bin/curl --silent --show-error --fail \
          --max-time 60 \
          "$warmup_url" >/dev/null 2>&1 &
      }

      is_recording_pid() {
        pid="$1"
        path="$2"

        [ -n "$pid" ] || return 1
        [ -r "/proc/$pid/cmdline" ] || return 1

        cmdline="$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
        case "$cmdline" in
          *"pw-record --channels 1 --rate 16000 --format s16 --volume 1.5 $path"*)
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      find_recording_pids() {
        path="$1"

        for proc in /proc/[0-9]*; do
          [ -r "$proc/cmdline" ] || continue

          pid="''${proc#/proc/}"
          cmdline="$(tr '\000' ' ' < "$proc/cmdline" 2>/dev/null || true)"

          case "$cmdline" in
            *"pw-record --channels 1 --rate 16000 --format s16 --volume 1.5 $path"*)
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
        mode="$1"
        pid=""
        path=""

        if [ -f "$pidfile" ]; then
          pid="$(tr -d '[:space:]' < "$pidfile" 2>/dev/null || true)"
        fi
        if [ -f "$pathfile" ]; then
          path="$(tr -d '[:space:]' < "$pathfile" 2>/dev/null || true)"
        fi

        if is_recording_pid "$pid" "$path"; then
          stop_pid "$pid"
        elif [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
          rm -f "$pidfile"
        fi

        if [ -f "$pidfile" ] && ! is_recording_pid "$pid" "$path"; then
          rm -f "$pidfile"
        fi

        # Full /proc scans are noticeably slower on the hot path, so only use
        # them as a fallback when stop couldn't identify the recorder from the pidfile.
        if [ "$mode" = stop ] && [ -n "$path" ] && ! is_recording_pid "$pid" "$path"; then
          for orphan_pid in $(find_recording_pids "$path"); do
            [ "$orphan_pid" = "$pid" ] && continue
            stop_pid "$orphan_pid"
          done
        fi

        if [ "$mode" = start ] && [ -n "$path" ]; then
          rm -f "$path" "$pathfile"
        fi
      }

      transcribe_and_type() {
        path="$1"

        if [ ! -f "$path" ]; then
          notify-send "Voice Input" "No audio recording found" -t 2000
          return 1
        fi

        if [ ! -s "$path" ] || [ "$(wc -c < "$path")" -le 44 ]; then
          notify-send "Voice Input" "Recorded audio was empty" -t 2000
          return 1
        fi

        response="$(${pkgs.curl}/bin/curl --silent --show-error --fail \
          --max-time 120 \
          -X POST "$api_url" \
          -F "file=@$path;type=audio/wav" \
          -F "model=$model" \
          -F "language=en")"

        text="$(printf '%s' "$response" | ${pkgs.jq}/bin/jq -r '.text // empty' | tr '\n' ' ' | tr -s ' ')"

        if [ -z "$text" ]; then
          notify-send "Voice Input" "Transcription returned no text" -t 2000
          return 1
        fi

        ${pkgs.wtype}/bin/wtype "$text"
      }

      command="''${1:-}"

      case "$command" in
        start)
          cleanup_stale_recording start
          warm_model
          recording_path="$runtime_dir/voice-recording-$(date +%s%N).wav"
          pw-record --channels 1 --rate 16000 --format s16 --volume 1.5 "$recording_path" >/dev/null 2>&1 &
          recording_pid="$!"
          printf '%s\n' "$recording_pid" > "$pidfile"
          printf '%s\n' "$recording_path" > "$pathfile"
          ;;
        stop)
          cleanup_stale_recording stop

          path=""
          if [ -f "$pathfile" ]; then
            path="$(tr -d '[:space:]' < "$pathfile" 2>/dev/null || true)"
          fi

          rm -f "$pidfile" "$pathfile"

          [ -n "$path" ] || exit 0

          if ! transcribe_and_type "$path"; then
            rm -f "$path"
            exit 1
          fi

          rm -f "$path"
          ;;
        *)
          printf 'usage: llama-dictate <start|stop>\n' >&2
          exit 1
          ;;
      esac
    '';
  };
in

{
  home.packages = [ llamaDictate ];
}
