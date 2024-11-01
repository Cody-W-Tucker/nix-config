{ pkgs }:

pkgs.writeShellScriptBin "bluetoothSwitch" ''
  device="74:74:46:1C:20:61"
  max_retries=3
  retry_count=0

  if bluetoothctl info "$device" | grep 'Connected: yes' -q; then
    bluetoothctl disconnect "$device"
  else
    while [ $retry_count -lt $max_retries ]; do
      bluetoothctl connect "$device" && break
      retry_count=$((retry_count + 1))
      echo "Retrying to connect... ($retry_count/$max_retries)"
      sleep 1
    done

    if [ $retry_count -eq $max_retries ]; then
      echo "Failed to connect after $max_retries attempts."
    fi
  fi
''
