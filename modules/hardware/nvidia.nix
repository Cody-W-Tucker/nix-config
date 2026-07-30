{
  config,
  ...
}:

{
  boot.kernelModules = [ "nvidia-uvm" ];

  hardware.nvidia = {
    open = true;
    powerManagement.enable = true;
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
}
