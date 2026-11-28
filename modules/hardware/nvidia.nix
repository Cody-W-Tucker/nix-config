{ den, ... }:
let
  exporterPort = 9835;
in
{
  den.aspects = {
    beast.includes = [ den.aspects.nvidia ];
    nas.includes = [ den.aspects.nvidia ];

    nvidia = {
      prometheus-targets =
        { host, ... }:
        {
          host = host.name;
          ports.nvidia-gpu = exporterPort;
        };

      nixos =
        {
          config,
          host,
          lib,
          ...
        }:
        {
          services = {
            xserver.videoDrivers = [ "nvidia" ];
            prometheus.exporters.nvidia-gpu = {
              enable = true;
              port = exporterPort;
            };
          };

          hardware.nvidia = {
            open = true;
            powerManagement.enable = true;
            nvidiaPersistenced = true;
            package = config.boot.kernelPackages.nvidiaPackages.production;
            nvidiaSettings = false;
            moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
          };

          networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
            config.services.prometheus.exporters.nvidia-gpu.port
          ];

          systemd.services = lib.optionalAttrs (host ? nvidiaPowerLimit) {
            nvidia-power-limit = {
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
                ExecStart = "${lib.getExe' config.hardware.nvidia.package "nvidia-smi"} -pl ${toString host.nvidiaPowerLimit}";
              };
            };
          };

          nixpkgs.config.cudaSupport = true;
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
    };
  };
}
