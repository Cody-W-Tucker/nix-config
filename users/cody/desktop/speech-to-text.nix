{
  pkgs,
  hardwareConfig ? { },
  ...
}:

let
  # WORKAROUND: wtype 0.4 assigns generated text to control-range keycodes, which Chromium/Electron can misinterpret.
  # https://github.com/atx/wtype/issues/71
  # https://github.com/atx/wtype/pull/74
  # https://github.com/atx/wtype/commit/4b4c4cbd22e57fa2dc03bc8a69f1f9e2fc7f220d
  # REVIEW-BY: 2026-11-30
  wtypeFixedKeycodes = pkgs.wtype.overrideAttrs (oa: {
    patches = (oa.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        url = "https://github.com/atx/wtype/commit/4b4c4cbd22e57fa2dc03bc8a69f1f9e2fc7f220d.patch";
        hash = "sha256-Ds1/PJ6wKuBQu1kgbHnIA7SXlKWMNbvoT+jfowFaMA8=";
      })
    ];
  });

  llamaDictate = pkgs.writeShellApplication {
    name = "llama-dictate";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.libnotify
      pkgs.pipewire
      wtypeFixedKeycodes
    ];
    text = ''
      set -euo pipefail

      pidfile="/tmp/llama-dictate-recording.pid"
      pathfile="/tmp/llama-dictate-recording.path"
      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
       api_url="http://nas:8081/v1/audio/transcriptions"
       warmup_url="http://nas:8081/upstream/whisper-medium/health"
       normalizer_warmup_url="http://nas:8081/upstream/s1-mini/health"
       model="whisper-medium"
      norm_url="http://nas:8081/v1/chat/completions"

       warm_model() {
         # Ask llama-swap to bring up both backends without sending fake requests.
         ${pkgs.curl}/bin/curl --silent --show-error --fail \
           --max-time 60 \
           "$warmup_url" >/dev/null 2>&1 &
         ${pkgs.curl}/bin/curl --silent --show-error --fail \
           --max-time 60 \
           "$normalizer_warmup_url" >/dev/null 2>&1 &
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

      find_any_recording_pids() {
        for proc in /proc/[0-9]*; do
          [ -r "$proc/cmdline" ] || continue

          pid="''${proc#/proc/}"
          cmdline="$(tr '\000' ' ' < "$proc/cmdline" 2>/dev/null || true)"

          case "$cmdline" in
            *"pw-record --channels 1 --rate 16000 --format s16 --volume 1.5 /run/user/"*"/voice-recording-"*".wav"*)
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
        stopped=0

        if [ -f "$pidfile" ]; then
          pid="$(tr -d '[:space:]' < "$pidfile" 2>/dev/null || true)"
        fi
        if [ -f "$pathfile" ]; then
          path="$(tr -d '[:space:]' < "$pathfile" 2>/dev/null || true)"
        fi

        if is_recording_pid "$pid" "$path"; then
          stop_pid "$pid"
          stopped=1
        elif [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
          rm -f "$pidfile"
        fi

        # If pid bookkeeping is stale but the path is still known, only look
        # for a recorder tied to that exact path. Avoid broad scans here so
        # normal start/stop stays immediate.
        if [ "$mode" = start ] && [ -n "$path" ] && [ "$stopped" -eq 0 ]; then
          for orphan_pid in $(find_recording_pids "$path"); do
            [ "$orphan_pid" = "$pid" ] && continue
            stop_pid "$orphan_pid"
            stopped=1
          done
        fi

        if [ -f "$pidfile" ] && ! is_recording_pid "$pid" "$path"; then
          rm -f "$pidfile"
        fi

        if [ "$mode" = start ] && [ "$stopped" -eq 1 ]; then
          rm -f "$pidfile" "$pathfile"
        fi

        if [ "$mode" = start ] && [ -n "$path" ] && [ "$stopped" -eq 0 ]; then
          rm -f "$path" "$pathfile"
        fi

        [ "$stopped" -eq 1 ]
      }

      recover_recording() {
        recovered=0

        for orphan_pid in $(find_any_recording_pids); do
          stop_pid "$orphan_pid"
          recovered=1
        done

        rm -f "$pidfile" "$pathfile"

        [ "$recovered" -eq 1 ]
      }

      normalize_text() {
        # Normalize raw Whisper output through the s1-mini chat-completions
        # endpoint. On any failure (network error, timeout, malformed/empty
        # response) this prints nothing, so the caller can fall back to the raw
        # transcript.
        text="$1"
        system_prompt="You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text."

        payload="$(printf '%s' "$text" | ${pkgs.jq}/bin/jq -R -s --arg sys "$system_prompt" '
          {
            model: "s1-mini",
            messages: [
              { role: "system", content: $sys },
              { role: "user", content: "[Styling: semi-formal] [Structure: lists] [Context: email]\n" + . }
            ]
          }')"

        ${pkgs.curl}/bin/curl --silent --show-error --fail \
          --max-time 60 \
          -X POST "$norm_url" \
          -H "Content-Type: application/json" \
          -d "$payload" \
          | ${pkgs.jq}/bin/jq -r '.choices[0].message.content? // empty'
      }

      finish_recording() {
        # Shared stop-and-transcribe path used by both `stop` and `toggle` so the
        # duplicate transcribe/cleanup logic lives in one place.
        cleanup_stale_recording stop || true

        path=""
        if [ -f "$pathfile" ]; then
          path="$(tr -d '[:space:]' < "$pathfile" 2>/dev/null || true)"
        fi

        rm -f "$pidfile" "$pathfile"

        [ -n "$path" ] || return 0

        if ! transcribe_and_type "$path"; then
          rm -f "$path"
          return 1
        fi

        rm -f "$path"
      }

      type_text_once() {
        # Type $1 as a single wtype process. Preserves full text segments and
        # maps every internal newline to Shift+Return in source order. Internal
        # blank lines are preserved; a terminal newline is NOT mapped to a
        # trailing Shift+Return. Text is passed through the argv array so it is
        # never re-split or shell-reinterpreted (no eval, no per-line loops).
        text="$1"
        args=()
        first=1
        while IFS= read -r segment || [ -n "$segment" ]; do
          if [ "$first" -eq 1 ]; then
            first=0
          else
            args+=(-M shift -k Return -m shift)
          fi
          args+=("$segment")
        done < <(printf '%s' "$text")

        [ "''${#args[@]}" -gt 0 ] || return 0
        ${wtypeFixedKeycodes}/bin/wtype "''${args[@]}"
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

        raw_text="$(printf '%s' "$response" | ${pkgs.jq}/bin/jq -r '.text // empty' | tr -s ' ')"
        raw_text="$(printf '%s' "$raw_text" | sed 's/^ *//;s/ *$//')"

        if [ -z "$raw_text" ]; then
          notify-send "Voice Input" "Transcription returned no text" -t 2000
          return 1
        fi

        # Normalize the raw transcript through s1-mini; fall back to the raw text
        # when normalization fails, times out, or returns nothing.
        cleaned="$(normalize_text "$raw_text" || true)"

        if [ -z "$cleaned" ]; then
          cleaned="$raw_text"
        fi

        # Type the cleaned transcript with one wtype process. Every internal
        # newline becomes Shift+Return (so target UIs insert a line break
        # instead of submitting), in source order, with full segments and blank
        # lines preserved. A single process avoids the per-line width/dropped
        # text bugs of the old per-line loop.
        type_text_once "$cleaned"
      }

      command="''${1:-}"

      case "$command" in
        start)
          if cleanup_stale_recording start; then
            exit 0
          fi
          warm_model
          recording_path="$runtime_dir/voice-recording-$(date +%s%N).wav"
          pw-record --channels 1 --rate 16000 --format s16 --volume 1.5 "$recording_path" >/dev/null 2>&1 &
          recording_pid="$!"
          printf '%s\n' "$recording_pid" > "$pidfile"
          printf '%s\n' "$recording_path" > "$pathfile"
          ;;
        stop)
          finish_recording || exit 1
          ;;
        toggle)
          # If already recording, stop and transcribe; otherwise start.
          if [ -f "$pidfile" ]; then
            pid="$(tr -d '[:space:]' < "$pidfile" 2>/dev/null || true)"
            path=""
            if [ -f "$pathfile" ]; then
              path="$(tr -d '[:space:]' < "$pathfile" 2>/dev/null || true)"
            fi
            if is_recording_pid "$pid" "$path"; then
              # Recording active — treat as stop.
              finish_recording || exit 1
              exit 0
            fi
            # Stale pid — fall through to start.
          fi
          cleanup_stale_recording start || true
          warm_model
          recording_path="$runtime_dir/voice-recording-$(date +%s%N).wav"
          pw-record --channels 1 --rate 16000 --format s16 --volume 1.5 "$recording_path" >/dev/null 2>&1 &
          recording_pid="$!"
          printf '%s\n' "$recording_pid" > "$pidfile"
          printf '%s\n' "$recording_path" > "$pathfile"
          ;;
        recover)
          recover_recording || true
          ;;
        *)
          printf 'usage: llama-dictate <start|stop|toggle|recover>\n' >&2
          exit 1
          ;;
      esac
    '';
  };
in

{
  home.packages = [ llamaDictate ];
}
