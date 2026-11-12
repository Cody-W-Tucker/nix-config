{
  config,
  lib,
  ...
}:

let
  cfg = config.codyos.hardware.nvidia;
in
{
  options.codyos.hardware.nvidia = {
    enable = lib.mkEnableOption "NVIDIA driver, CUDA, and GPU monitoring";
    powerLimit.enable = lib.mkEnableOption "persistent nvidia-smi GPU power cap (oneshot after driver load)";
    powerLimit.watts = lib.mkOption {
      type = lib.types.ints.positive;
      default = 123;
      description = ''
        nvidia-smi -pl value. RTX 5060 LP on nas reports min 123 W / max 145 W;
        values below the card min will fail the unit.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Load nvidia driver for Xorg and Wayland. Even on headless installs, this is vital to installing the nvidia drivers.
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      open = true;
      powerManagement.enable = true;
      nvidiaPersistenced = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      nvidiaSettings = false;
    };

    # NVIDIA GPU monitoring for Prometheus
    services.prometheus.exporters.nvidia-gpu.enable = true;

    # NVIDIA GPU exporter: scraped by the NAS Prometheus over Tailscale (localhost on the NAS).
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      config.services.prometheus.exporters.nvidia-gpu.port
    ];

    systemd.services.nvidia-power-limit = lib.mkIf cfg.powerLimit.enable {
      description = "Cap NVIDIA GPU board power (nvidia-smi -pl)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "nvidia-persistenced.service"
        "systemd-udev-settle.service"
      ];
      wants = [ "nvidia-persistenced.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe' config.hardware.nvidia.package "nvidia-smi"} -pl ${toString cfg.powerLimit.watts}";
      };
    };

    # Build apps with CUDA support
    nixpkgs.config.cudaSupport = true;
    # CUDA licences are covered by the global nixpkgs.config.allowUnfree (system/nix.nix).

    # CUDA binary cache to avoid building from source
    nix.settings = {
      extra-substituters = [
        "https://cache.nixos-cuda.org"
        "https://cache.flox.dev"
      ];
      extra-trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      ];
    };
  };
}
