{ pkgs }:

pkgs.writeShellScriptBin "bluetoothSwitch" ''
  device="74:74:46:1C:20:61"
  
  # Check if the Bluetooth device is connected
  if bluetoothctl info "$device" | grep 'Connected: yes' -q; then
    echo "Device is connected. Disconnecting..."
    bluetoothctl disconnect "$device"
  else
    echo "Device not connected. Trying to connect..."
    bluetoothctl connect "$device"
  fi
''
