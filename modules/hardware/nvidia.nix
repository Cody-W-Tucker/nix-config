{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nvidia-power-limit;
in
{
  options.services.nvidia-power-limit = {
    enable = lib.mkEnableOption "persistent nvidia-smi GPU power cap (oneshot after driver load)";
    watts = lib.mkOption {
      type = lib.types.ints.positive;
      default = 123;
      description = ''
        nvidia-smi -pl value. RTX 5060 LP on nas reports min 123 W / max 145 W;
        values below the card min will fail the unit.
      '';
    };
  };

  config = {
    boot.kernelModules = [ "nvidia-uvm" ];

    environment.systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
      nvidia-vaapi-driver
    ];

    # Load nvidia driver for Xorg and Wayland. Even on headless installs, this is vital to installing the nvidia drivers.
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      open = true;
      powerManagement.enable = true;
      nvidiaPersistenced = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      nvidiaSettings = false;
    };

    # NVIDIA container toolkit for CUDA container access
    hardware.nvidia-container-toolkit.enable = true;

    # NVIDIA GPU monitoring for Prometheus
    services.prometheus.exporters.nvidia-gpu = {
      enable = true;
      port = 9835;
    };

    # Open firewall for NVIDIA GPU exporter
    networking.firewall.allowedTCPPorts = [ 9835 ];

    systemd.services.nvidia-power-limit = lib.mkIf cfg.enable {
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
        ExecStart = "${lib.getExe' config.hardware.nvidia.package "nvidia-smi"} -pl ${toString cfg.watts}";
      };
    };

    # Build apps with CUDA support
    nixpkgs.config.cudaSupport = true;
    nixpkgs.config.allowUnfreePredicate =
      p:
      builtins.all (
        license:
        license.free
        || builtins.elem license.shortName [
          "CUDA EULA"
          "cuDNN EULA"
          "cuTENSOR EULA"
          "NVidia OptiX EULA"
        ]
      ) (if builtins.isList p.meta.license then p.meta.license else [ p.meta.license ]);

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
