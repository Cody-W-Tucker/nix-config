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
    ../modules/services/headroom
    ../modules/desktop/hardware/rocm.nix
    ../modules/services/llama-swap
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

    # AMD XDNA NPU driver configuration
    # Note: The NPU (amdxdna) is currently disabled because:
    # 1. Upstream linux-firmware has broken npu.sbin symlinks for Strix Halo (17f0_11)
    # 2. No official upstream NPU user-space tools yet (rocmlir, xrt plugin, etc.)
    # 3. Driver logs firmware errors on every Boot

    # To re-enable in the future:
    # - Remove the blacklist below
    # - Add boot.kernelModules = [ "amdxdna" ]
    # - Fix firmware symlinks or wait for upstream linux-firmware fix

    # Blacklist the NPU driver to prevent boot errors
    blacklistedKernelModules = [ "amdxdna" ];

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

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/73998e5d-b64f-4148-bacb-af7b7883746a";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/BD3E-2CD9";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
    "/home/codyt/Documents" = {
      device = "/mnt/backup/Share/Documents";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };
    "/home/codyt/Knowledge/Personal" = {
      device = "/mnt/backup/Obsidian";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };
    "/home/codyt/Music" = {
      device = "/mnt/backup/Share/Music";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };
    "/home/codyt/Pictures" = {
      device = "/mnt/backup/Share/Pictures";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };
    "/home/codyt/Videos" = {
      device = "/mnt/backup/Share/Videos";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };
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

  services = {
    llama-swap = {
      # Hot loading models from llama-cpp
      enable = true;
      acceleration = "rocm";
      port = 8080;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      modelOwner = "codyt";
      modelGroup = "users";
      enabledModels = [ "qwen3.5-35b" ];
      preloadModels = [ "qwen3.5-35b" ];
      modelOverrides."qwen3.5-35b" = {
        contextSize = 65536;
        cacheTypeK = "q8_0";
        cacheTypeV = "q6_k"; # or q8_0 for zero quality loss, q4_k for max speed
        batchSize = 2048;
        ubatchSize = 512;
        threads = 16;
        gpuLayers = 999;
      };
    };
    headroom = {
      # Smart context compression service - proxies llama-swap
      enable = true;
      listenAddress = "0.0.0.0";
      openFirewall = true;
      port = 8787;
      upstream = {
        kind = "openai-compatible";
        baseUrl = "http://localhost:8080";
      };
      serviceEnvironment = {
        # Disable GPU for Kompress compression (ROCm/MIOpen errors)
        HIP_VISIBLE_DEVICES = "";
        CUDA_VISIBLE_DEVICES = "";
      };
      memory = {
        enable = true;
        dbPath = "/var/lib/headroom/headroom-memory.db";
      };
    };
    promtail.configuration.scrape_configs = [
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
  };

  system.stateVersion = "25.11"; # Don't change
}
