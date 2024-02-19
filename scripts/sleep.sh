#!/usr/bin/env bash

# This script is used to lock the screen after a certain time of inactivity.

swayidle -w timeout 900 'swaylock -f -c 000000' \
            timeout 1800 'hyprctl dispatch dpms off' \
            resume 'hyprctl dispatch dpms on' \
            timeout 2700 'systemctl suspend' \
            before-sleep 'swaylock -f -c 000000' &
