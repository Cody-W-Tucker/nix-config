#!/bin/bash
#     _         _        _            _     
#    / \  _   _| |_ ___ | | ___   ___| | __ 
#   / _ \| | | | __/ _ \| |/ _ \ / __| |/ / 
#  / ___ \ |_| | || (_) | | (_) | (__|   <  
# /_/   \_\__,_|\__\___/|_|\___/ \___|_|\_\ 
#                                           
# by Stephan Raabe (2023) 
# ----------------------------------------------------- 

# This script is used to lock the screen after a certain time of inactivity.

swayidle -w timeout 1800 'swaylock -f -c 000000' \
            timeout 3600 'systemctl suspend' \
            before-sleep 'swaylock -f -c 000000' &
