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
    TRANSCRIPTION_ERROR=""

    # Check if model file exists
    if [ ! -f "$MODEL_PATH" ]; then
      TRANSCRIPTION_ERROR="Model file not found: $MODEL_PATH"
    else
      # Transcribe with error capture
      WHISPER_OUTPUT=$(${pkgs.whisper-cpp}/bin/whisper-cli \
        -m "$MODEL_PATH" \
        -f "$RECORDING_FILE" \
        --output-txt \
        --output-file "$TEMP_DIR/transcription" \
        --no-timestamps \
        --language en \
        --threads 8 2>&1)
      WHISPER_EXIT=$?

      # Check if transcription command succeeded
      if [ $WHISPER_EXIT -ne 0 ]; then
        TRANSCRIPTION_ERROR="Transcription failed (exit code $WHISPER_EXIT): $(echo "$WHISPER_OUTPUT" | tail -5)"
      elif [ ! -f "$TRANSCRIPTION_FILE" ]; then
        TRANSCRIPTION_ERROR="No transcription output file created"
      elif [ ! -s "$TRANSCRIPTION_FILE" ]; then
        TRANSCRIPTION_ERROR="Transcription file is empty - audio may be silent or unintelligible"
      fi
    fi

    # Check if transcription was successful
    if [ -z "$TRANSCRIPTION_ERROR" ] && [ -f "$TRANSCRIPTION_FILE" ]; then
      TEXT=$(cat "$TRANSCRIPTION_FILE" | sed 's/^ *//;s/ *$//')
      
      if [ -n "$TEXT" ]; then
        # Type word by word for faster perceived speed
        echo "$TEXT" | tr ' ' '\n' | while read -r word; do
          if [ -n "$word" ]; then
            ${pkgs.ydotool}/bin/ydotool type --key-delay 1 --key-hold 1 "$word "
          fi
        done
      else
        TRANSCRIPTION_ERROR="Transcription produced no text"
      fi
    fi

    # Handle errors
    if [ -n "$TRANSCRIPTION_ERROR" ]; then
      # Send desktop notification
      if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "Dictation Error" "$TRANSCRIPTION_ERROR"
      fi
      # Log error for debugging
      echo "[$(date)] $TRANSCRIPTION_ERROR" >> /tmp/whisper-dictate-errors.log
    fi

    # Cleanup
    rm -f "$TRANSCRIPTION_FILE" "$RECORDING_FILE"
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
  ];

  # Enable ydotool daemon for typing text
  programs.ydotool.enable = true;
}
