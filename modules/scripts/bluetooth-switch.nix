{ pkgs }:

pkgs.writeShellScriptBin "bluetoothSwitch" ''
  device="74:74:46:1C:20:61"
  max_retries=5
  retry_count=0
  
  # Check if the Bluetooth device is connected
  if bluetoothctl info "$device" | grep 'Connected: yes' -q; then
    echo "Device is connected. Disconnecting..."
    bluetoothctl disconnect "$device"
    sleep 2  # Give time for the disconnect process to complete.
  else
    echo "Device not connected. Trying to connect..."
    while [ $retry_count -lt $max_retries ]; do
      # Attempt to connect
      if bluetoothctl connect "$device"; then
        echo "Connected to $device on attempt #$((retry_count+1))."
        break
      else
        retry_count=$((retry_count + 1))
        echo "Failed to connect. Retrying... ($retry_count/$max_retries)"
        sleep 3  # Increase the sleep time between retries.
      fi
    done
    
    # If all attempts fail
    if [ $retry_count -eq $max_retries ]; then
      echo "Failed to connect after $max_retries attempts."
    fi
  fi
''
