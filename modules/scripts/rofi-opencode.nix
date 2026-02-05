{ pkgs }:
pkgs.writeShellApplication {
  name = "rofi-opencode";
  runtimeInputs = [
    pkgs.rofi
    pkgs.zsh
    pkgs.direnv
  ];
  text = ''
    #!/usr/bin/env zsh
    source "$HOME/.zshenv"  # Load user PATH, direnv hook, etc.

    # Kill rofi if already running
    if pgrep -x "rofi" > /dev/null; then
      pkill -x rofi
      exit 0
    fi

    # Step 1: Select project directory
    PROJECT_DIR="$HOME/Projects"

    # Get list of directories, excluding files
    selected_dir=$(find "$PROJECT_DIR" -maxdepth 1 -type d -printf "%f\n" |
      sort |
      ${pkgs.rofi}/bin/rofi -dmenu -i -p "Select Project" \
      -theme-str 'listview { columns: 1; }')

    # Exit if no selection
    [[ -z "$selected_dir" ]] && exit 0

    # Step 2: Get command input
    command=$(echo "" | ${pkgs.rofi}/bin/rofi -dmenu -p "Opencode Command" -l 0)

    # Exit if no command
    [[ -z "$command" ]] && exit 0

    # Step 3: Launch kitty with interactive shell for direnv support
    env | grep -E '(PATH|DIRENV|HOME)' || echo "❌ Missing user env vars!"
    uwsm app -- kitty --directory "$PROJECT_DIR/$selected_dir" \
      zsh -i -c "opencode --model 'xai/grok-code-fast-1' run '$command'"
  '';
}
