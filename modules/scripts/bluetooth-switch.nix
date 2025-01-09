{ pkgs }:

pkgs.writeShellScriptBin "bluetoothSwitch" ''
  device="74:74:46:1C:20:61"
  max_attempts=3
  
  check_controller() {
    if ! bluetoothctl show | grep 'Powered: yes' -q; then
      echo "Controller is powered off. Powering on..."
      bluetoothctl power on
      sleep 2
    fi
  }
  
  connect_device() {
    bluetoothctl connect "$device"
    sleep 2
    bluetoothctl info "$device" | grep 'Connected: yes' -q
  }
  
  cycle_bluetooth() {
    bluetoothctl power off
    sleep 2
    bluetoothctl power on
    sleep 2
  }
  
  # Ensure controller is powered on first
  check_controller
  
  # Check current connection state
  if bluetoothctl info "$device" | grep 'Connected: yes' -q; then
    echo "Device is connected. Disconnecting..."
    bluetoothctl disconnect "$device"
  else
    echo "Device not connected. Attempting to connect..."
    
    attempt=1
    while [ $attempt -le $max_attempts ]; do
      if connect_device; then
        echo "Successfully connected on attempt $attempt"
        exit 0
      fi
      
      echo "Connection attempt $attempt failed"
      cycle_bluetooth
      attempt=$((attempt + 1))
    done
    
    echo "Failed to connect after $max_attempts attempts"
    exit 1
  fi
''
