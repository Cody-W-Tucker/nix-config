{ pkgs, ... }:

let
  # Configuration
  modelDir = "$HOME/.local/share/whisper/models";
  tempDir = "/tmp/whisper-dictate-$UID";
  modelName = "ggml-base.bin";

  # Start recording script
  dictationStart = pkgs.writeShellScriptBin "whisper-dictate-start" ''
    # Configuration
    MODEL_DIR="${modelDir}"
    TEMP_DIR="${tempDir}"
    RECORDING_FILE="$TEMP_DIR/recording.wav"
    MODEL_PATH="$MODEL_DIR/${modelName}"
    PID_FILE="$TEMP_DIR/recording.pid"

    # Ensure directories exist
    mkdir -p "$MODEL_DIR"
    mkdir -p "$TEMP_DIR"

    # Check if model exists, download if not
    if [ ! -f "$MODEL_PATH" ]; then
      ${pkgs.whisper-cpp}/bin/whisper-cpp-download-ggml-model base "$MODEL_DIR/"
    fi

    # Clean up old files
    rm -f "$RECORDING_FILE"

    # Check if already recording
    if [ -f "$PID_FILE" ]; then
      OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
      if kill -0 "$OLD_PID" 2>/dev/null; then
        # Already recording, do nothing
        exit 0
      fi
    fi

    # Start recording in background (no time limit)
    ${pkgs.ffmpeg}/bin/ffmpeg -f pulse -i default -ar 16000 -ac 1 -acodec pcm_s16le -y "$RECORDING_FILE" 2>/dev/null &
    FFMPEG_PID=$!

    # Save PID
    echo $FFMPEG_PID > "$PID_FILE"
  '';

  # Stop recording and transcribe script
  dictationStop = pkgs.writeShellScriptBin "whisper-dictate-stop" ''
    # Configuration
    MODEL_DIR="${modelDir}"
    TEMP_DIR="${tempDir}"
    RECORDING_FILE="$TEMP_DIR/recording.wav"
    TRANSCRIPTION_FILE="$TEMP_DIR/transcription.txt"
    MODEL_PATH="$MODEL_DIR/${modelName}"
    PID_FILE="$TEMP_DIR/recording.pid"

    # Check if recording is happening
    if [ ! -f "$PID_FILE" ]; then
      exit 0
    fi

    FFMPEG_PID=$(cat "$PID_FILE" 2>/dev/null)

    # Stop recording
    if [ -n "$FFMPEG_PID" ]; then
      kill -TERM "$FFMPEG_PID" 2>/dev/null || true
      sleep 0.5
      kill -KILL "$FFMPEG_PID" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"

    # Check if recording exists and has content
    if [ ! -f "$RECORDING_FILE" ] || [ ! -s "$RECORDING_FILE" ]; then
      exit 0
    fi

    # Clean up old transcription
    rm -f "$TRANSCRIPTION_FILE"

    # Transcribe
    ${pkgs.whisper-cpp}/bin/whisper-cli \
      -m "$MODEL_PATH" \
      -f "$RECORDING_FILE" \
      --output-txt \
      --output-file "$TEMP_DIR/transcription" \
      --no-timestamps \
      --language en \
      --threads 4 2>/dev/null

    # Check if transcription was successful
    if [ -f "$TRANSCRIPTION_FILE" ]; then
      TEXT=$(cat "$TRANSCRIPTION_FILE" | sed 's/^ *//;s/ *$//')
      
      if [ -n "$TEXT" ]; then
        # Try to type with ydotool first
        sleep 0.3
        if ${pkgs.ydotool}/bin/ydotool type --key-delay 20 --key-hold 20 "$TEXT" 2>/dev/null; then
          # Typing succeeded, no need to copy to clipboard
          :
        else
          # Typing failed, copy to clipboard as fallback
          echo "$TEXT" | ${pkgs.wl-clipboard}/bin/wl-copy
        fi
      fi
      
      # Cleanup
      rm -f "$TRANSCRIPTION_FILE" "$RECORDING_FILE"
    fi
  '';

in
{
  # Install the dictation scripts and dependencies
  environment.systemPackages = with pkgs; [
    dictationStart
    dictationStop
    whisper-cpp
    ydotool
    ffmpeg
    wl-clipboard
  ];

  # Enable ydotool daemon for typing text
  programs.ydotool.enable = true;
}
