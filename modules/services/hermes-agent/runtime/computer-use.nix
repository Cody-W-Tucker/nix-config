{
  hermesCuaDriver,
  lib,
  pkgs,
  ...
}:

let
  cuaDriverCommand = pkgs.writeShellApplication {
    name = "hermes-cua-driver";
    runtimeInputs = with pkgs; [
      at-spi2-core
      coreutils
      grim
      imagemagick
      scrot
      systemd
      xwd
      xwininfo
    ];
    text = ''
      uid="$(id -u)"

      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$uid"
      fi
      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      fi

      # Hermes runs as a system service with User=..., so it does not inherit
      # the Hyprland/UWSM GUI environment. UWSM publishes that environment to
      # the user's systemd manager; recover the session variables before the
      # driver starts, without replacing this wrapper's tool PATH.
      manager_environment="$(systemctl --user show-environment 2>/dev/null || true)"
      if [ -n "$manager_environment" ]; then
        while IFS= read -r assignment; do
          case "$assignment" in
            *=*) ;;
            *) continue ;;
          esac

          name="''${assignment%%=*}"
          value="''${assignment#*=}"
          case "$name" in
            AT_SPI_BUS_ADDRESS|DBUS_SESSION_BUS_ADDRESS|DESKTOP_SESSION|DISPLAY|GDK_BACKEND|HYPRLAND_INSTANCE_SIGNATURE|I3SOCK|KDE_FULL_SESSION|KDE_SESSION_VERSION|MOZ_ENABLE_WAYLAND|QT_QPA_PLATFORM|SWAYSOCK|WAYLAND_DISPLAY|XAUTHORITY|XCURSOR_SIZE|XCURSOR_THEME|XDG_CURRENT_DESKTOP|XDG_DESKTOP_PORTAL_DIR|XDG_RUNTIME_DIR|XDG_SESSION_DESKTOP|XDG_SESSION_TYPE)
              export "''${name?}=$value"
              ;;
          esac
        done < <(printf '%s\n' "$manager_environment")
      fi

      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$uid"
      fi
      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      fi

      if [ -z "''${XAUTHORITY:-}" ]; then
        for candidate in \
          "$XDG_RUNTIME_DIR/.Xauthority" \
          "$XDG_RUNTIME_DIR/Xauthority" \
          "$HOME/.Xauthority"
        do
          if [ -f "$candidate" ]; then
            export XAUTHORITY="$candidate"
            break
          fi
        done

        if [ -z "''${XAUTHORITY:-}" ]; then
          for candidate in "$XDG_RUNTIME_DIR"/*xauth* "$XDG_RUNTIME_DIR"/*Xauthority*; do
            if [ -f "$candidate" ]; then
              export XAUTHORITY="$candidate"
              break
            fi
          done
        fi
      fi

      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        wayland_candidate=""
        wayland_count=0
        for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
          if [ -S "$socket" ]; then
            wayland_candidate="$(basename "$socket")"
            wayland_count=$((wayland_count + 1))
          fi
        done
        if [ "$wayland_count" -eq 1 ]; then
          export WAYLAND_DISPLAY="$wayland_candidate"
        fi
      fi

      if [ -z "''${DISPLAY:-}" ]; then
        display_candidate=""
        display_count=0
        for socket in /tmp/.X11-unix/X*; do
          if [ -S "$socket" ]; then
            display_number="''${socket##*/X}"
            case "$display_number" in
              ""|*[!0-9]*) continue ;;
            esac
            display_candidate=":$display_number"
            display_count=$((display_count + 1))
          fi
        done
        if [ "$display_count" -eq 1 ]; then
          export DISPLAY="$display_candidate"
        fi
      fi

      if [ -z "''${XDG_SESSION_TYPE:-}" ]; then
        if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          export XDG_SESSION_TYPE="wayland"
        elif [ -n "''${DISPLAY:-}" ]; then
          export XDG_SESSION_TYPE="x11"
        fi
      fi

      if [ -z "''${DISPLAY:-}" ]; then
        printf '%s\n' \
          'hermes-cua-driver: no DISPLAY/XWayland session was found.' \
          "" \
          "cua-driver's Linux capture path currently depends on X11/XWayland tools" \
          'such as xwd, ImageMagick import, scrot, and XGetImage. Wayland-only' \
          'sessions without XWayland are therefore unlikely to capture successfully.' \
          "" \
          'Action: enable XWayland for the Hyprland session and make sure UWSM has' \
          'finalized/imported the GUI environment into systemd --user. Check with:' \
          "  systemctl --user show-environment | grep -E '^(DISPLAY|WAYLAND_DISPLAY)='" >&2
        exit 1
      fi

      export CUA_DRIVER_RS_ENABLE_WAYLAND="''${CUA_DRIVER_RS_ENABLE_WAYLAND:-1}"
      exec ${lib.getExe hermesCuaDriver} mcp "$@"
    '';
  };
in
{
  _module.args.hermesComputerUseRuntime = {
    command = cuaDriverCommand;
    extraPackages = [
      pkgs.at-spi2-core
      pkgs.grim
      pkgs.imagemagick
      pkgs.scrot
      pkgs.xwd
      pkgs.xwininfo
    ];
    serviceEnvironment = {
      CUA_DRIVER_RS_ENABLE_WAYLAND = "1";
      HERMES_CUA_DRIVER_CMD = lib.getExe cuaDriverCommand;
    };
  };
}
