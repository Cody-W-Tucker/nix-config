{ pkgs }:

pkgs.writeShellScriptBin "wallpaper" ''
  # This script will randomly go through the files of a directory, setting it
  # up as the wallpaper at regular intervals
  #
  # NOTE: this script uses bash (not POSIX shell) for the RANDOM variable

  # Edit below to control the images transition
  export SWWW_TRANSITION_FPS=60
  export SWWW_TRANSITION_STEP=2
  export SWWW_TRANSITION_TYPE=random

  # This controls (in seconds) when to switch to the next image
  INTERVAL=1500

  # Define the wallpaper directory
  wallpaperDir="/etc/nixos/modules/wallpapers"

  # Function to set a random wallpaper
  set_random_wallpaper() {
    if [ -d "$wallpaperDir" ]; then
      find ''${wallpaperDir} \
        | while read -r img; do
            echo "$((RANDOM % 1000)):$img"
        done \
        | sort -n | cut -d':' -f2- \
        | head -n 1 \
        | while read -r img; do
            swww img "$img"
        done
    else
      echo "Directory $wallpaperDir not found"
      sleep 10
    fi
  }

  # Set a random wallpaper immediately
  set_random_wallpaper

  while true; do
    sleep $INTERVAL
    set_random_wallpaper
  done
''
