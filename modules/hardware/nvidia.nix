{
  # NVIDIA driver, CUDA, and GPU monitoring. Included by every host with an NVIDIA GPU.
  # nixpkgs.config.cudaSupport is host-wide (pkgs.unstable inherits it through the overlay).
  # A host that caps GPU board power sets the `nvidiaPowerLimit` host attribute (watts,
  # modules/hosts/<host>.nix); the card's minimum applies, e.g. RTX 5060 LP reports
  # min 123 W / max 145 W and values below it fail the unit.
  den.aspects.nvidia.nixos =
    {
      config,
      host,
      lib,
      ...
    }:
    {
      # Load nvidia driver for Xorg and Wayland. Even on headless installs, this is vital to installing the nvidia drivers.
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        open = true;
        powerManagement.enable = true;
        nvidiaPersistenced = true;
        package = config.boot.kernelPackages.nvidiaPackages.production;
        nvidiaSettings = false;
        # With 595+ kernel suspend notifiers, VRAM is otherwise saved to kernel RAM at
        # suspend, which intermittently fails (NV_ERR_NO_MEMORY) and breaks resume.
        moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
      };

      # NVIDIA GPU monitoring for Prometheus
      services.prometheus.exporters.nvidia-gpu.enable = true;

      # NVIDIA GPU exporter: scraped by the NAS Prometheus over Tailscale (localhost on the NAS).
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

      # Build apps with CUDA support
      nixpkgs.config.cudaSupport = true;
      # CUDA licences are covered by the global nixpkgs.config.allowUnfree (base/nix.nix).

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
