{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Main work workstation. GMKtec-evo2 APU: Strix Halo AI 395+ Max | 2TB NVMe

let
  hardwareConfig = {
    # Top monitor should be DP-1
    workspace = [
      "1, monitor:DP-1, default:true"
    ];
    monitor = [
      "DP-1,3840x2160@240,0x0,1.5"
    ];
    # Never suspend
    hypridle.suspendTimeout = null;
    # Disable speech-to-text on this host (avoid long builds)
    enableWhisp = false;
  };
in
{
  imports = [
    ../modules/system/base.nix
    ../modules/desktop
    ../modules/desktop/hardware/rocm.nix
    ../modules/services/llama-swap-strix.nix
    # Using community hardware nixosConfigurations
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
  ];

  # Home-manager configuration with hardware-specific settings
  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
      inherit hardwareConfig;
    };
    users.codyt = {
      imports = [
        ../users/cody/ui.nix
        ../secrets/home-secrets.nix
        inputs.nixvim.homeModules.nixvim
      ];
    };
  };

  # Bootloader
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    kernelParams = [
      "amd_pstate=active"
      "iommu=pt"
      "amdgpu.gttsize=94208"
    ];

    # Use newest kernel
    kernelPackages = pkgs.linuxPackages_latest;

    # Keep BIOS UMA small and let TTM/GTT provide the large shared pool.
    # 24,117,248 pages = 92 GiB of dynamically mappable GPU memory.

    extraModprobeConfig = ''
      options ttm pages_limit=24117248
    '';

    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "sdhci_pci"
    ];
    kernelModules = [
      "kvm-amd"
    ];
  };

  networking = {
    hostName = "aiserver";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/73998e5d-b64f-4148-bacb-af7b7883746a";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/BD3E-2CD9";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # User home directories
  fileSystems."/home/codyt/Documents" = {
    device = "/mnt/backup/Share/Documents";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Music" = {
    device = "/mnt/backup/Share/Music";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Pictures" = {
    device = "/mnt/backup/Share/Pictures";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Videos" = {
    device = "/mnt/backup/Share/Videos";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Knowledge/Personal" = {
    device = "/mnt/backup/Obsidian";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 65536; # 64GB swap file to handle memory-intensive builds
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # llama-swap with ROCm-optimized llama.cpp for Strix Halo
  services.llama-swap-strix.enable = true;

  systemd.tmpfiles.rules = [
    "d /srv/llama-swap 0755 root root - -"
    "d /srv/llama-swap/models 0755 codyt users - -"
  ];

  # Configure llama-swap using upstream options
  services.llama-swap = {
    port = 8080;
    listenAddress = "0.0.0.0";
    openFirewall = true;

    settings =
      let
        llama-cpp = config.services.llama-swap-strix.serverPackage;
        llama-server = lib.getExe' llama-cpp "llama-server";
        modelDir = "/srv/llama-swap/models";
      in
      {
        healthCheckTimeout = 60;
        logLevel = "info";
        logToStdout = "both";

        hooks.on_startup.preload = [ "qwen3.5-35b" ];

        models = {
          "qwen3.5-35b" = {
            cmd = "${llama-server} --port \${PORT} -m ${modelDir}/Qwen3.5-35B-A3B-Q8_0.gguf --alias qwen3.5-35b --no-webui --flash-attn on --n-gpu-layers 999 -c 65536 -b 2048 -ub 1024 -t 16";
            ttl = 600;
          };
        };
      };
  };

  # AMD XDNA NPU driver configuration
  # Note: The NPU (amdxdna) is currently disabled because:
  # 1. Upstream linux-firmware has broken npu.sbin symlinks for Strix Halo (17f0_11)
  # 2. No official upstream NPU user-space tools yet (rocmlir, xrt plugin, etc.)
  # 3. Driver logs firmware errors on every boot
  #
  # To re-enable in the future:
  # - Remove the blacklist below
  # - Add boot.kernelModules = [ "amdxdna" ]
  # - Fix firmware symlinks or wait for upstream linux-firmware fix

  # Blacklist the NPU driver to prevent boot errors
  boot.blacklistedKernelModules = [ "amdxdna" ];

  # Renaming the logging client to machine hostname
  services.promtail.configuration.scrape_configs = [
    {
      job_name = "journal";
      journal = {
        max_age = "12h";
        labels = {
          job = "systemd-journal";
          host = "aiserver";
        };
      };
      relabel_configs = [
        {
          source_labels = [ "__journal__systemd_unit" ];
          target_label = "unit";
        }
      ];
    }
  ];

  system.stateVersion = "25.11"; # Don't change
}
