# EC-SU_AXB35 monitor script for GMKtec EVO-X2
# Provides real-time fan speeds, temperatures, and power mode display
{ pkgs, ... }:
pkgs.writeShellScriptBin "ec-su-axb35-monitor" ''
  #!/usr/bin/env bash

  SYSFS_BASE="/sys/class/ec_su_axb35"

  # Check if module is loaded
  if [ ! -d "$SYSFS_BASE" ]; then
    echo "Error: ec_su_axb35 module not loaded"
    echo "Run: sudo modprobe ec_su_axb35"
    exit 1
  fi

  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color

  # Display header
  clear
  echo "EC-SU_AXB35 Monitor (GMKtec EVO-X2)"
  echo "===================================="
  echo ""

  # APU Power Mode
  echo "Power Mode: $(cat $SYSFS_BASE/apu/power_mode)"
  echo ""

  # Fan information
  echo "Fan Status:"
  echo "-----------"
  for fan in fan1 fan2 fan3; do
    if [ -d "$SYSFS_BASE/$fan" ]; then
      echo "  $fan:"
      echo "    Mode:  $(cat $SYSFS_BASE/$fan/mode)"
      echo "    Level: $(cat $SYSFS_BASE/$fan/level)"
      if [ -r "$SYSFS_BASE/$fan/rpm" ]; then
        echo "    RPM:   $(cat $SYSFS_BASE/$fan/rpm)"
      fi
    fi
  done
  echo ""

  # Temperatures (if available)
  if [ -r "$SYSFS_BASE/thermal/cpu_temp" ]; then
    echo "Temperatures:"
    echo "-----------"
    echo "  CPU:  $(cat $SYSFS_BASE/thermal/cpu_temp)°C"
    if [ -r "$SYSFS_BASE/thermal/apu_temp" ]; then
      echo "  APU:  $(cat $SYSFS_BASE/thermal/apu_temp)°C"
    fi
  fi
''
