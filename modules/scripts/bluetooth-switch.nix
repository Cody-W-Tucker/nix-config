{ pkgs }:

pkgs.writeShellScriptBin "bluetoothSwitch" ''
  device="74:74:46:1C:20:61"
  max_retries=5
  retry_count=0
  timeout=10

  # Function to check if Bluetooth is powered on
  check_bluetooth_power() {
    if ! bluetoothctl show | grep -q "Powered: yes"; then
      echo "Bluetooth is not powered on. Attempting to power on..."
      bluetoothctl power on
      sleep 2
    fi
  }

  # Function to attempt connection
  connect_device() {
    bluetoothctl connect "$device"
  }

  # Check Bluetooth power status
  check_bluetooth_power

  if bluetoothctl info "$device" | grep -q 'Connected: yes'; then
    echo "Device is already connected. Disconnecting..."
    bluetoothctl disconnect "$device"
  else
    echo "Attempting to connect to device..."
    while [ $retry_count -lt $max_retries ]; do
      if timeout $timeout connect_device; then
        echo "Successfully connected to device."
        break
      fi
      retry_count=$((retry_count + 1))
      echo "Connection attempt $retry_count failed. Retrying in 2 seconds..."
      sleep 2
    done

    if [ $retry_count -eq $max_retries ]; then
      echo "Failed to connect after $max_retries attempts."
      echo "Trying to remove and re-pair the device..."
      bluetoothctl remove "$device"
      sleep 2
      bluetoothctl scan on &
      sleep 5
      bluetoothctl scan off
      bluetoothctl pair "$device"
      sleep 2
      connect_device
    fi
  fi

  # Final connection check
  if bluetoothctl info "$device" | grep -q 'Connected: yes'; then
    echo "Device is now connected."
  else
    echo "Failed to connect to the device."
  fi
''
