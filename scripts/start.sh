#!/usr/bin/env bash

waybar &
mako &

swww init &
BACK_PID=$!
wait $BACK_PID

# Add a delay to give swww time to fully initialize
sleep 1

swww img /home/codyt/Pictures/Wallpapers/space3.png