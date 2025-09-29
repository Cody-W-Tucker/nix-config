{ pkgs }:

pkgs.writeShellScriptBin "bluetoothSwitchDBus" ''
  device_mac="74:74:46:1C:20:61"
  device_path="/org/bluez/hci0/dev_$(echo $device_mac | sed 's/:/_/g')"
  adapter_path="/org/bluez/hci0"
  max_attempts=5
  sleep_time=5
  
  # Unblock Bluetooth
  rfkill unblock bluetooth
  sleep 2
  
  get_prop() {
    dbus-send --system --dest=org.bluez --print-reply=literal $1 org.freedesktop.DBus.Properties.Get string:org.bluez.$2 string:$3 | awk '{print $3}'
  }
  
  set_prop() {
    dbus-send --system --dest=org.bluez --print-reply $1 org.freedesktop.DBus.Properties.Set string:org.bluez.$2 string:$3 variant:boolean:$4 > /dev/null
  }
  
  check_controller() {
    powered=$(get_prop $adapter_path Adapter1 Powered)
    if [ "$powered" != "true" ]; then
      echo "Controller is powered off. Powering on..."
      set_prop $adapter_path Adapter1 Powered true
      sleep $sleep_time
    fi
  }
  
  trust_device() {
    trusted=$(get_prop $device_path Device1 Trusted)
    if [ "$trusted" != "true" ]; then
      echo "Trusting device..."
      set_prop $device_path Device1 Trusted true
      sleep 2
    fi
  }
  
  connect_device() {
    dbus-send --system --dest=org.bluez --print-reply $device_path org.bluez.Device1.Connect > /dev/null 2>&1
    for i in {1..5}; do
      sleep 1
      connected=$(get_prop $device_path Device1 Connected)
      if [ "$connected" = "true" ]; then
        return 0
      fi
    done
    return 1
  }
  
  disconnect_device() {
    dbus-send --system --dest=org.bluez --print-reply $device_path org.bluez.Device1.Disconnect > /dev/null
  }
  
  cycle_bluetooth() {
    set_prop $adapter_path Adapter1 Powered false
    sleep $sleep_time
    set_prop $adapter_path Adapter1 Powered true
    sleep $sleep_time
  }
  
  check_controller
  
  trust_device
  
  connected=$(get_prop $device_path Device1 Connected)
  if [ "$connected" = "true" ]; then
    echo "Device is connected. Disconnecting..."
    disconnect_device
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
