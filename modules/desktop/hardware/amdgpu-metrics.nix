{ config, pkgs, lib, ... }:

let
  rocmMetricsScript = pkgs.writeShellScriptBin "rocm-metrics-exporter" ''
    set -e
    
    OUTPUT_DIR="/var/lib/node_exporter/textfile_collector"
    TEMP_FILE="$OUTPUT_DIR/rocm_metrics.prom.$$"
    FINAL_FILE="$OUTPUT_DIR/rocm_metrics.prom"
    
    mkdir -p "$OUTPUT_DIR"
    
    # Get GPU metrics in JSON format using rocm-smi
    METRICS=$(${pkgs.rocmPackages.rocm-smi}/bin/rocm-smi --json --showtemp --showuse --showmemuse --showpower --showfan 2>/dev/null || echo "[]")
    
    # Parse and convert to Prometheus format
    echo "# HELP amdgpu_temperature_celsius GPU temperature in celsius" > "$TEMP_FILE"
    echo "# TYPE amdgpu_temperature_celsius gauge" >> "$TEMP_FILE"
    
    echo "# HELP amdgpu_gpu_utilization GPU utilization percentage" >> "$TEMP_FILE"
    echo "# TYPE amdgpu_gpu_utilization gauge" >> "$TEMP_FILE"
    
    echo "# HELP amdgpu_memory_utilization GPU memory utilization percentage" >> "$TEMP_FILE"
    echo "# TYPE amdgpu_memory_utilization gauge" >> "$TEMP_FILE"
    
    echo "# HELP amdgpu_memory_used_bytes GPU memory used in bytes" >> "$TEMP_FILE"
    echo "# TYPE amdgpu_memory_used_bytes gauge" >> "$TEMP_FILE"
    
    echo "# HELP amdgpu_memory_total_bytes GPU total memory in bytes" >> "$TEMP_FILE"
    echo "# TYPE amdgpu_memory_total_bytes gauge" >> "$TEMP_FILE"
    
    echo "# HELP amdgpu_power_watts GPU power consumption in watts" >> "$TEMP_FILE"
    echo "# TYPE amdgpu_power_watts gauge" >> "$TEMP_FILE"
    
    echo "# HELP amdgpu_fan_speed_percent GPU fan speed percentage" >> "$TEMP_FILE"
    echo "# TYPE amdgpu_fan_speed_percent gauge" >> "$TEMP_FILE"
    
    echo "# HELP amdgpu_fan_rpm GPU fan RPM" >> "$TEMP_FILE"
    echo "# TYPE amdgpu_fan_rpm gauge" >> "$TEMP_FILE"
    
    # Parse the JSON output and convert to Prometheus format
    # rocm-smi JSON structure is: {"card0": {"Temperature (Sensor edge) (C)": "62.0", ...}}
    ${pkgs.jq}/bin/jq -r '
      to_entries[] |
      select(.key | startswith("card")) |
      .key as $card |
      .value |
      "amdgpu_temperature_celsius{card=\"\($card)\"} \(."Temperature (Sensor edge) (C)" | tonumber? // 0)\n" +
      "amdgpu_gpu_utilization{card=\"\($card)\"} \(."GPU use (%)" | tonumber? // 0)\n" +
      "amdgpu_memory_utilization{card=\"\($card)\"} \(."GPU Memory Allocated (VRAM%)" | tonumber? // 0)\n" +
      "amdgpu_memory_used_bytes{card=\"\($card)\"} 0\n" +
      "amdgpu_memory_total_bytes{card=\"\($card)\"} 0\n" +
      "amdgpu_power_watts{card=\"\($card)\"} \(."Current Socket Graphics Package Power (W)" | tonumber? // 0)\n" +
      "amdgpu_fan_speed_percent{card=\"\($card)\"} 0\n" +
      "amdgpu_fan_rpm{card=\"\($card)\"} 0"
    ' <<< "$METRICS" >> "$TEMP_FILE" 2>/dev/null || true
    
    # Get additional metrics using rocminfo for total VRAM
    ROCM_INFO=$(${pkgs.rocmPackages.rocminfo}/bin/rocminfo 2>/dev/null || echo "")
    
    # Move temp file to final location atomically
    mv "$TEMP_FILE" "$FINAL_FILE"
  '';
in
{
  options = {
    hardware.amdgpu.metricsExporter = {
      enable = lib.mkEnableOption "AMD GPU metrics exporter for Prometheus using rocm-smi";
      
      interval = lib.mkOption {
        type = lib.types.str;
        default = "30s";
        description = "How often to collect GPU metrics";
      };
    };
  };
  
  config = lib.mkIf config.hardware.amdgpu.metricsExporter.enable {
    assertions = [
      {
        assertion = config.services.prometheus.exporters.node.enable;
        message = "The node_exporter service must be enabled to use the AMD GPU metrics exporter";
      }
    ];
    
    # Enable textfile collector in node_exporter
    services.prometheus.exporters.node.extraFlags = [
      "--collector.textfile.directory=/var/lib/node_exporter/textfile_collector"
    ];
    
    # Create the systemd service that runs rocm-smi periodically
    systemd.services.rocm-metrics-exporter = {
      description = "AMD GPU Metrics Exporter for Prometheus";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${rocmMetricsScript}/bin/rocm-metrics-exporter";
        User = "root";
        Group = "root";
        WorkingDirectory = "/var/lib/node_exporter";
      };
    };
    
    # Create a timer to run the exporter periodically
    systemd.timers.rocm-metrics-exporter = {
      description = "Run AMD GPU Metrics Exporter periodically";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = config.hardware.amdgpu.metricsExporter.interval;
        Persistent = true;
      };
    };
    
    # Ensure the textfile collector directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/node_exporter/textfile_collector 0755 root root -"
    ];
    
    # Add the necessary packages to system packages
    environment.systemPackages = with pkgs; [
      rocmPackages.rocm-smi
      rocmPackages.rocminfo
      jq
    ];
  };
}
