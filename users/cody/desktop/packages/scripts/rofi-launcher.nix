{ pkgs }:

pkgs.writeShellApplication {
  name = "rofi-launcher";
  runtimeInputs = [
    pkgs.procps
    pkgs.rofi
  ];
  text = ''
    set -euo pipefail

    if pgrep -x "rofi" > /dev/null; then
      # Rofi is running, kill it
      pkill -x rofi
      exit 0
    fi

    rofi -show drun -run-command "focus-or-run '{cmd}' 'uwsm-app -- {cmd}'"
  '';
}
