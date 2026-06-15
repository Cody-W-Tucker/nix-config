{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}:

# Main home desktop workstation: CPU: i9-14900kf | GPU: Nvidia 3070 | RAM: 64GB | Storage: 2TB & 2 1TB Drives(unmapped) NVMe SSD

let
  hardwareConfig = {
    # Controls the monitor layout for hyprland
    workspace = [ "1, monitor:DP-1, default:true" ];
    monitor = [
      "DP-1,2560x1440@239.97,0x0,1,bitdepth,10,vrr,2"
    ];
    # Suspend after 2 hours of idle
    hypridle.suspendTimeout = 7200;
    # Use CUDA for whisper (faster than Vulkan on Nvidia)
    whispAcceleration = "cuda";
  };

  # Keep the faster-whisper weights on the workspace volume so Open WebUI STT
  # and whisp-away reuse one model download.
  sharedFasterWhisperCache = "/mnt/work/cache/ai/faster-whisper";
  workBtrfsMembers = [
    "/dev/disk/by-partlabel/work-a"
    "/dev/disk/by-partlabel/work-b"
  ];
  workBtrfsMountOptions = map (device: "device=${device}") workBtrfsMembers ++ [
    "subvolid=5"
    "compress=zstd"
    "noatime"
    "discard=async"
  ];
  llamaAudioCompatPython = pkgs.python313.withPackages (
    ps: with ps; [
      accelerate
      datasets
      fastapi
      faster-whisper
      python-multipart
      sentencepiece
      soundfile
      torch
      transformers
      uvicorn
    ]
  );
  outettsFemaleSpeaker = pkgs.fetchurl {
    name = "outetts-en-female-1.json";
    url = "https://raw.githubusercontent.com/edwko/OuteTTS/0.2.2/outetts.js/version/v1/default_speakers/en_female_1.json";
    hash = "sha256-nEMEdKoHH8mM+1tQN0RofgbFlnt72GQ9unXBTUTUFfs=";
  };
in
{
  imports = [
    ../modules/system/base.nix
    ../modules/desktop
    ../modules/desktop/gaming
    ../modules/desktop/hardware/nvidia.nix
    ../modules/services/llama-swap
    ../modules/services/hermes-agent
    ../modules/server/ai

    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  # Home-manager configuration with hardware-specific settings
  home-manager = {
    extraSpecialArgs = {
      inherit inputs self;
      inherit hardwareConfig;
    };
    users.codyt = {
      home.stateVersion = "25.05";
      imports = [
        ../users/cody/desktop.nix
        ../secrets/home-secrets.nix
        inputs.nixvim.homeModules.nixvim
      ];
    };
  };

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    initrd.availableKernelModules = [
      "vmd"
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    kernelModules = [
      "kvm-intel"
      "btusb"
    ];
    extraModprobeConfig = ''
      options btusb enable_autosuspend=n reset=1
      options mt7925e disable_aspm=Y
    '';
  };

  # Networking
  networking = {
    hostName = "beast";
    networkmanager.enable = true;
    networkmanager.settings.connection = {
      # MT7925 Bluetooth is more stable when NetworkManager does not power-save Wi-Fi.
      "wifi.powersave" = 2;
    };
    useDHCP = lib.mkDefault true; # Enables DHCP on each ethernet and wireless interface.
  };

  # System Docker is required for the Actual Budget MCP wrapper.
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Ensure 14th Gen Intel CPU works correctly
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # System fileSystems
  fileSystems = {
    # Actual drives
    "/" = {
      device = "/dev/disk/by-uuid/8a65acd3-482f-4e10-81c9-d814616564c6";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/36FA-44EF";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
    # Since we use syncthing to keep cody's home dirs synced we map these drives one by one.
    "/home/codyt/Documents" = {
      device = "/mnt/backup/Share/Documents";
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
    "/mnt/server-books" = {
      device = "192.168.1.31:/mnt/media/Media/Books";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "nfsvers=4.2"
      ];
    };
    "/mnt/work" = {
      device = "/dev/disk/by-uuid/34882b6b-6f50-4caa-93ff-b27688c41f1a";
      fsType = "btrfs";
      options = workBtrfsMountOptions;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/work/dev 0755 codyt users - -"
    "d /mnt/work/dev/hermes 2770 hermes hermes - -"
    "d /mnt/work/vm 0755 codyt users - -"
    "d /mnt/work/cache 0755 codyt users - -"
    "d /mnt/work/media 0755 codyt users - -"
    "d /mnt/work/cache/ai 0755 codyt users - -"
    "d ${sharedFasterWhisperCache} 0755 codyt users - -"
  ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "*-*-01 09:00:00";
    fileSystems = [ "/mnt/work" ];
  };

  # Spread the monthly scrub over a window so it rarely collides with
  # suspend transitions (this host sleeps after 2 h of idle).
  systemd.timers."btrfs-scrub-mnt-work".timerConfig.RandomizedDelaySec = "3h";

  systemd.services."btrfs-scrub-mnt-work" = {
    after = [ "mnt-work.mount" ];
    requires = [ "mnt-work.mount" ];
  };

  systemd.services.work-btrfs-nocow = {
    description = "Apply NOCOW attribute to workspace heavy-write directories";
    wantedBy = [ "multi-user.target" ];
    after = [
      "mnt-work.mount"
    ];
    requires = [
      "mnt-work.mount"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "work-btrfs-nocow" ''
        set -eu

        # Apply NOCOW to empty directories so future VM images and caches avoid CoW overhead.
        ${pkgs.e2fsprogs}/bin/chattr +C /mnt/work/vm
        ${pkgs.e2fsprogs}/bin/chattr +C /mnt/work/cache
      '';
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 65536; # 64GB swap file to handle memory-intensive builds
    }
  ];

  services.llama-swap = {
    enable = true;
    acceleration = "cuda";
    port = 8081;
    modelOwner = "codyt";
    modelGroup = "users";
    serviceEnvironment = {
      # Wrapper processes still need a writable private cache for other
      # Hugging Face assets such as SpeechT5 TTS files.
      HF_HOME = "/var/cache/llama-swap/huggingface";
      XDG_CACHE_HOME = "/var/cache/llama-swap";
      LD_LIBRARY_PATH = lib.concatStringsSep ":" [
        "/run/opengl-driver/lib"
        "/run/current-system/sw/lib"
      ];
    };
    enabledModels = [
      "qwen3.5-0.8b"
      "qwen3.5-4b"
      "qwen3-embedding-0.6b"
      "glm-ocr-f16"
      "whisper-medium"
      "outetts-0.2-500m"
      "transformers-speecht5"
    ];
    preloadModels = [ "whisper-medium" ];
    settings.groups = {
      audio-stt = {
        swap = false;
        exclusive = false;
        persistent = false;
        members = [ "whisper-medium" ];
      };
      audio-tts = {
        swap = false;
        exclusive = false;
        persistent = false;
        members = [
          "outetts-0.2-500m"
          "transformers-speecht5"
        ];
      };
    };
    modelOverrides = {
      # qwen3.5-4b is used by Karakeep for summarization. Disable reasoning so
      # the <think> trace does not consume the context budget.
      "qwen3.5-4b" = {
        contextSize = 32768;
        ttl = 60;
        extraArgs = [
          "--reasoning"
          "off"
        ];
      };
      "qwen3.5-0.8b" = {
        extraArgs = [
          "--parallel"
          "4"
        ];
      };
      # Embeddings traffic here is short-form; use a smaller KV/cache footprint and
      # avoid flash-attn to reduce startup instability in llama-server.
      "qwen3-embedding-0.6b" = {
        contextSize = 8192;
        batchSize = 1024;
        ubatchSize = 512;
        flashAttention = false;
      };
      # OCR prefers deterministic decoding. Allow a small amount of request
      # parallelism, but keep batching modest on the 3070 now that this host
      # uses the larger F16 weights.
      "glm-ocr-f16" = {
        batchSize = 1024;
        ubatchSize = 512;
        extraArgs = [
          "--parallel"
          "2"
          "--samplers"
          "top_k"
          "--top-k"
          "1"
          "--temp"
          "0"
        ];
      };
      "whisper-medium" = {
        ttl = 0; # Keep STT warm until another group explicitly evicts it.
        upstream = {
          cmd = ''
            ${llamaAudioCompatPython}/bin/python3 ${../modules/services/llama-swap/faster-whisper-openai-server.py} \
              --host 127.0.0.1 \
              --port ''${PORT} \
              --model medium.en \
              --model-id whisper-medium \
              --device cuda \
              --compute-type int8 \
              --download-root ${sharedFasterWhisperCache} \
              --vad-filter \
              --language en
          '';
        };
      };
      "outetts-0.2-500m" = {
        ttl = 300;
        upstream = {
          cmd = ''
            ${llamaAudioCompatPython}/bin/python3 ${../modules/services/llama-swap/llama-tts-openai-server.py} \
              --host 127.0.0.1 \
              --port ''${PORT} \
              --model ${config.services.llama-swap.modelDirectory}/OuteTTS-0.2-500M-Q8_0.gguf \
              --vocoder ${config.services.llama-swap.modelDirectory}/WavTokenizer-Large-75-F16.gguf \
              --llama-tts ${lib.getExe' config.services.llama-swap.serverPackage "llama-tts"} \
              --speaker-file ${outettsFemaleSpeaker} \
              --model-id outetts-0.2-500m
          '';
        };
      };
      "transformers-speecht5" = {
        ttl = 300; # 5 min idle before llama-swap considers unloading (voice stack)
        upstream = {
          cmd = ''
            ${llamaAudioCompatPython}/bin/python3 ${../modules/services/llama-swap/transformers-tts-openai-server.py} \
              --host 127.0.0.1 \
              --port ''${PORT} \
              --model-id transformers-speecht5 \
              --device cuda
          '';
        };
      };
    };
  };

  systemd.services.llama-swap.serviceConfig = {
    CacheDirectory = "llama-swap";
    ProcSubset = lib.mkForce "all";
    ProtectProc = lib.mkForce "default";
    DynamicUser = lib.mkForce false;
    User = "codyt";
    Group = "users";
    ReadWritePaths = lib.mkAfter [ sharedFasterWhisperCache ];
  };

  services.fluent-bit.settings.pipeline.inputs = [
    {
      name = "systemd";
      tag = "journal";
      read_from_tail = true;
      strip_underscores = true;
      lowercase = true;
    }
  ];

  # Should be the same as the version of NixOS you installed on this machine.
  system.stateVersion = "25.05"; # Did you read the comment?
}
