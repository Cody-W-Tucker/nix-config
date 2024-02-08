#!/bin/bash

# Select random wallpaper and create color scheme
wal -q -i ~/Pictures/Wallpapers/space3.png

# Load color scheme
source "$HOME/.cache/wal/colors.sh"

# Copy color file to waybar folder
cp ~/.cache/wal/colors-waybar.css ~/Code/dotfiles/waybar/