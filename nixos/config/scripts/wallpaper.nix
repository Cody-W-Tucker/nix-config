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
  INTERVAL=900

  # Define the wallpaper directory
  wallpaperDir="$HOME/Pictures/Wallpapers"

  while true; do
  	if [ -d "$wallpaperDir" ]; then
  		find ''${wallpaperDir} \
  			| while read -r img; do
  				echo "$((RANDOM % 1000)):$img"
  			done \
  			| sort -n | cut -d':' -f2- \
  			| while read -r img; do
  				swww img "$img"
  				sleep $INTERVAL
  			done
  	else
  		echo "Directory $wallpaperDir not found"
  		sleep 10
  	fi
  done
''
