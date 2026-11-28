pidfile="/tmp/llama-dictate-recording.pid"
pathfile="/tmp/llama-dictate-recording.path"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
api_url="$base_url/v1/audio/transcriptions"
warmup_url="$base_url/upstream/fluid-speech-pro-clean/health"
normalizer_warmup_url="$base_url/upstream/s1-mini/health"
model="fluid-speech-pro-clean"
norm_url="$base_url/v1/chat/completions"
transcription_id=""

warm_model() {
  # Ask llama-swap to bring up both backends without sending fake requests.
  curl --silent --show-error --fail \
    --max-time 60 \
    "$warmup_url" >/dev/null 2>&1 &
  curl --silent --show-error --fail \
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

    pid="${proc#/proc/}"
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

    pid="${proc#/proc/}"
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
  # Print nothing on failure so the caller can use the raw transcript.
  text="$1"
  system_prompt="You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text."

  payload="$(printf '%s' "$text" | jq -R -s --arg sys "$system_prompt" '
    {
      model: "s1-mini",
      max_tokens: 2048,
      temperature: 0,
      messages: [
        { role: "system", content: $sys },
        { role: "user", content: "[Styling: semi-formal] [Structure: lists] [Context: email]\n" + . }
      ]
    }')"

  response="$(curl --silent --show-error --fail \
    --max-time 60 \
    -X POST "$norm_url" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    | jq -r '.choices[0].message.content? // empty')" || return 1

  [ -n "$response" ] || return 1

  # Reject unreasonable output before typing: a reasoning model that
  # leaks or truncates its <think> scratch, or returns far more text
  # than was dictated, is not a usable normalization.
  case "$response" in
    *"<think>"*|*"</think>"*) return 1 ;;
  esac

  raw_bytes="$(printf '%s' "$text" | wc -c)"
  response_bytes="$(printf '%s' "$response" | wc -c)"
  [ "$response_bytes" -le $((raw_bytes * 3 + 200)) ] || return 1

  printf '%s' "$response"
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

  [ "${#args[@]}" -gt 0 ] || return 0
  wtype "${args[@]}"
}

request_transcript() {
  # Prints the response JSON; .id is set when the NAS recorded it in speech-history.
  curl --silent --show-error --fail \
    --max-time 120 \
    -X POST "$api_url" \
    -F "file=@$1;type=audio/wav" \
    -F "model=$2" \
    -F "language=en"
}

apply_history() {
  # Record the normalized text against the transcription and apply the
  # vocabulary rules again, since s1-mini may reintroduce a misspelling.
  # Print nothing on failure so the caller types the text it has.
  [ -n "$transcription_id" ] || return 1
  jq -n --arg text "$1" '{text: $text}' \
    | curl --silent --show-error --fail --max-time 5 \
        -X POST "$history_url/transcriptions/$transcription_id/final" \
        -H "Content-Type: application/json" -d @- \
    | jq -r '.text // empty'
}

fix_last() {
  last="$(curl --silent --show-error --fail --max-time 5 "$history_url/last")" || {
    notify-send "Voice Input" "No dictation to fix" -t 2000
    return 1
  }
  id="$(printf '%s' "$last" | jq -r '.id')"
  # rofi edits one line; corrections are compared word by word, so
  # flattening line breaks loses nothing.
  text="$(printf '%s' "$last" | jq -r '.text' | tr '\n' ' ' | tr -s ' ' | sed 's/^ *//;s/ *$//')"
  corrected="$(rofi -dmenu -p "Fix" -filter "$text" -l 0 < /dev/null)" || return 0
  [ -n "$corrected" ] && [ "$corrected" != "$text" ] || return 0

  result="$(jq -n --arg text "$corrected" '{text: $text}' \
    | curl --silent --show-error --fail --max-time 5 \
        -X POST "$history_url/transcriptions/$id/correction" \
        -H "Content-Type: application/json" -d @-)" || {
    notify-send "Voice Input" "Could not save the correction" -t 3000
    return 1
  }
  summary="$(printf '%s' "$result" | jq -r '
    [(.learned[] | "Learned: \(.from) → \(.to)"),
     (.pending[] | "Noted (common words): \(.from) → \(.to)")] | join("\n")')"
  notify-send "Voice Input" "${summary:-Saved; no word-level fix found}" -t 4000
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

  response="$(request_transcript "$path" "$model" || true)"
  raw_text="$(printf '%s' "$response" | jq -r '.text // empty' 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//')"
  transcription_id="$(printf '%s' "$response" | jq -r '.id // empty' 2>/dev/null)"

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

  final="$(apply_history "$cleaned" || true)"
  if [ -n "$final" ]; then
    cleaned="$final"
  fi

  # Type the cleaned transcript with one wtype process. Every internal
  # newline becomes Shift+Return (so target UIs insert a line break
  # instead of submitting), in source order, with full segments and blank
  # lines preserved. A single process avoids the per-line width/dropped
  # text bugs of the old per-line loop.
  type_text_once "$cleaned"
}

command="${1:-}"

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
  fix)
    fix_last || exit 1
    ;;
  vocabulary)
    # Active rules in the format of llama-swap/_speech-vocabulary.json.
    curl --silent --show-error --fail "$history_url/vocabulary" | jq .
    ;;
  suggestions)
    # Common-word corrections that are never applied automatically.
    curl --silent --show-error --fail "$history_url/suggestions" | jq .
    ;;
  forget)
    [ -n "${2:-}" ] || { printf 'usage: llama-dictate forget <from>\n' >&2; exit 1; }
    curl --silent --show-error --fail -X DELETE -G "$history_url/vocabulary" \
      --data-urlencode "from=$2" | jq .
    ;;
  *)
    printf 'usage: llama-dictate <start|stop|toggle|recover|fix|vocabulary|suggestions|forget FROM>\n' >&2
    exit 1
    ;;
esac
