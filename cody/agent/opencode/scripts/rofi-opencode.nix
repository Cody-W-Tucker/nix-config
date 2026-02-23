{ pkgs }:
pkgs.writeShellApplication {
  name = "rofi-opencode";
  runtimeInputs = [
    pkgs.rofi
    pkgs.zsh
    pkgs.direnv
  ];
  text = ''
    # Kill rofi if already running
    if pgrep -x "rofi" > /dev/null; then
      pkill -x rofi
      exit 0
    fi

    # Step 1: Select project directory
    PROJECT_DIR="$HOME/Projects"

    # Get list of directories, excluding files
    dirs=$(find "$PROJECT_DIR" -maxdepth 1 -type d -printf "%f\n" | sort)
    selected_dir=$(echo -e "$dirs\nnixos" | sort -u |
      ${pkgs.rofi}/bin/rofi -dmenu -i -p "Select Project" \
      -theme-str 'listview { columns: 1; }')

    # Exit if no selection
    [[ -z "$selected_dir" ]] && exit 0

    # Step 2: Get command input
    command=$(echo "" | ${pkgs.rofi}/bin/rofi -dmenu -p "Opencode Command" -l 0)

    # Exit if no command
    [[ -z "$command" ]] && exit 0

    # Step 3: Launch kitty with interactive shell for direnv support
    if [[ "$selected_dir" == "nixos" ]]; then
      target_dir="/etc/nixos"
    else
      target_dir="$PROJECT_DIR/$selected_dir"
      if [[ ! -d "$target_dir" ]]; then
        echo "Project directory $target_dir does not exist." >&2
        exit 1
      fi
    fi

    env | grep -E '(PATH|DIRENV|HOME)' || echo "❌ Missing user env vars!"
    uwsm app -- kitty --directory "$target_dir" \
      zsh -i -c "opencode run '$command'"
  '';
}
