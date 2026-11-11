# Beast Desktop Workstation

`beast` is the primary high-performance CodyOS desktop. This directory owns the host-specific detail for hardware, storage, local inference, and desktop tuning.

Central docs should point here instead of duplicating this host map.

## Layout

Host policy (identity, features, network mounts, networking, Docker, and desktop `hardwareConfig`) lives in `default.nix`; machine hardware lives in `hardware-configuration.nix`.

| Path          | Role                                                                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `default.nix` | Host policy: `codyos.*` features, kernel choice, NAS network mounts, networking (incl. Wake-on-LAN), `hardwareConfig` for Hyprland, Home Manager entry. |
| `hardware-configuration.nix` | Hardware: root and EFI filesystems, initrd/kernel modules, MT7925 Wi-Fi/Bluetooth quirks, `nixos-hardware` profiles. |

## Hardware profile

| Component | Configuration                                                  |
| --------- | -------------------------------------------------------------- |
| CPU       | Intel Core i9-14900KF, 24 cores / 32 threads.                  |
| GPU       | NVIDIA RTX 3070, 8GB VRAM.                                     |
| RAM       | 16GB DDR5 6000                                                 |
| Storage   | 2TB NVMe root (`ext4`); EFI system partition on vfat.          |
| Kernel    | Latest Linux kernel via `pkgs.linuxPackages_latest`.           |
| NIC       | `eno1` with magic-packet Wake-on-LAN (NAS can wake this host). |
| Razer     | OpenRazer + Polychromatic (`modules/desktop/hardware/openrazer`). Effects synced across devices; daemon restores last lighting on login. |

The host is tuned for CUDA inference on demand, software development, 4K/high-refresh desktop use, and gaming. Always-on AI chat/RAG and agent runtime live on the NAS; beast supplies heavier GPU-backed models when awake.
