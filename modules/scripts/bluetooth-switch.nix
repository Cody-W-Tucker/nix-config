{ pkgs }:

let
  force_repair = false; # Set to true for initial setup or to fix pairing issues
in
pkgs.writeShellScriptBin "bluetoothSwitch" ''
  device_mac="74:74:46:1C:20:61"
  max_attempts=3
  sleep_time=3
  force_repair=${if force_repair then "true" else "false"}

  # Unblock Bluetooth
  rfkill unblock bluetooth
  sleep 2

  # Helper to run bluetoothctl commands non-interactively
  btcmd() {
    echo "$*" | bluetoothctl
  }

  # Check if connected
  is_connected() {
    btcmd "info $device_mac" 2>/dev/null | grep -q "Connected: yes"
  }

  # Check if device is known
  is_known() {
    btcmd "devices" 2>/dev/null | grep -q "$device_mac"
  }

  # Check if paired
  is_paired() {
    btcmd "info $device_mac" 2>/dev/null | grep -q "Paired: yes"
  }

  # Check if trusted
  is_trusted() {
    btcmd "info $device_mac" 2>/dev/null | grep -q "Trusted: yes"
  }

  # Remove device if forced or not paired
  remove_device() {
    if [ "$force_repair" = "true" ] || ! is_paired; then
      if is_known; then
        echo "Removing existing device entry..."
        btcmd "remove $device_mac"
        sleep $sleep_time
      fi
      return 0
    fi
    return 1  # Not removed
  }

  # Connect with scan if needed
  connect_device() {
    if is_paired && is_trusted; then
      echo "Device paired and trusted. Connecting directly..."
      btcmd "connect $device_mac"
    else
      echo "Device not paired or trusted. Scanning for pairing..."
      echo "  -> Put Pixel Buds in pairing mode NOW (open case, hold back button 3-5s until LED flashes)"
      btcmd "
        power on
        agent on
        default-agent
        scan on
      "
      sleep 5  # Time to trigger pairing mode
      btcmd "scan off"
      if ! is_known; then
        echo "Device not found during scan. Ensure Pixel Buds are in discoverable mode and retry."
        return 1
      fi
      btcmd "pair $device_mac"
      sleep 1
      btcmd "trust $device_mac"
      sleep 1
      btcmd "connect $device_mac"
    fi

    # Wait and check
    for i in {1..10}; do
      sleep 1
      if is_connected; then
        echo "Connected!"
        return 0
      fi
    done
    return 1
  }

  # Disconnect
  disconnect_device() {
    btcmd "disconnect $device_mac"
    sleep 1
  }

  # Reset Bluetooth service
  reset_bluetooth() {
    echo "Restarting Bluetooth service..."
    systemctl restart bluetooth
    sleep $sleep_time
  }

  if is_connected; then
    echo "Device is connected. Disconnecting..."
    disconnect_device
    exit 0
  else
    echo "Device not connected. Attempting to connect..."

    attempt=1
    while [ $attempt -le $max_attempts ]; do
      remove_device  # Only removes if force_repair=true or not paired
      if connect_device; then
        echo "Successfully connected on attempt $attempt"
        exit 0
      fi

      echo "Connection attempt $attempt failed"
      reset_bluetooth
      attempt=$((attempt + 1))
    done

    echo "Failed to connect after $max_attempts attempts."
    echo "Try setting force_repair=true in the script and ensure Pixel Buds are in pairing mode."
    echo "Or manually pair via: bluetoothctl -> scan on -> pair $device_mac -> trust $device_mac -> connect $device_mac"
    exit 1
  fi
''
