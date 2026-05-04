{
  inputs,
  pkgs,
  hardwareConfig ? { },
  ...
}:

let
  whisp-gate = pkgs.writeShellScriptBin "whisp-gate" ''
    #!/usr/bin/env bash
    LOCKFILE="/run/user/1000/whisp-away.lock"
    MAX_DURATION=30  # Maximum recording time in seconds

    case "$1" in
      start)
        if [ -f "$LOCKFILE" ]; then
          OLD_PID=$(cat "$LOCKFILE")
          if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Recording already in progress (PID: $OLD_PID). Stopping it first."
            kill "$OLD_PID" 2>/dev/null
            rm -f "$LOCKFILE"
            sleep 0.5
          fi
        fi
        
        # Start new recording with timeout
        ${pkgs.coreutils}/bin/timeout --signal=TERM "$MAX_DURATION" whisp-away start &
        NEW_PID=$!
        echo $NEW_PID > "$LOCKFILE"
        
        echo "Recording started (max ''${MAX_DURATION}s)"
        
        # Wait and clean up lockfile when done
        wait $NEW_PID
        rm -f "$LOCKFILE"
        ;;
        
      stop)
        if [ -f "$LOCKFILE" ]; then
          PID=$(cat "$LOCKFILE")
          kill "$PID" 2>/dev/null
          rm -f "$LOCKFILE"
        fi
        whisp-away stop
        echo "Recording stopped"
        ;;
        
      status)
        if [ -f "$LOCKFILE" ]; then
          PID=$(cat "$LOCKFILE")
          if kill -0 "$PID" 2>/dev/null; then
            echo "Recording in progress (PID: $PID)"
            exit 0
          else
            rm -f "$LOCKFILE"
            echo "Stale lockfile cleaned"
          fi
        fi
        echo "No active recording"
        ;;
        
      *)
        echo "Usage: whisp-gate {start|stop|status}"
        exit 1
        ;;
    esac
  '';
in
{
  imports = [ inputs.whisp-away.nixosModules.home-manager ];

  home.packages = [ whisp-gate ];

  services.whisp-away = {
    enable = hardwareConfig.enableWhisp or true;
    defaultModel = "base.en";
    defaultBackend = "whisper-cpp";
    # Use acceleration from hardware config, fallback to CPU for fast builds
    accelerationType = hardwareConfig.whispAcceleration or "cpu";
    useClipboard = false;
    useCrane = false;
  };
}
