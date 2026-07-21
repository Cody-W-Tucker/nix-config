# Beast Desktop Workstation

`beast` is the primary high-performance CodyOS desktop. This directory owns the host-specific detail for hardware, storage, local inference, and desktop tuning.

Central docs should point here instead of duplicating this host map.

## Layout

Host-local files were collapsed into two Nix files. Machine identity, drives, networking, Docker, and desktop `hardwareConfig` live in `default.nix`. The llama-swap catalog stays separate.

| Path          | Role                                                                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `default.nix` | Full host definition: boot/kernel, filesystems, networking (incl. Wake-on-LAN), Docker, `hardwareConfig` for Hyprland, Home Manager entry. |
| `models.nix`  | Local `llama-swap` enablement, CUDA acceleration, model catalog, Whisper/Kokoro wrappers.                                                  |

## Hardware profile

| Component | Configuration                                                  |
| --------- | -------------------------------------------------------------- |
| CPU       | Intel Core i9-14900KF, 24 cores / 32 threads.                  |
| GPU       | NVIDIA RTX 3070, 8GB VRAM.                                     |
| RAM       | 16GB DDR5 6000                                                 |
| Storage   | 2TB NVMe root (`ext4`); EFI system partition on vfat.          |
| Kernel    | Latest Linux kernel via `pkgs.linuxPackages_latest`.           |
| NIC       | `eno1` with magic-packet Wake-on-LAN (NAS can wake this host). |

The host is tuned for CUDA inference on demand, software development, 4K/high-refresh desktop use, and gaming. Always-on AI chat/RAG and agent runtime live on the NAS; beast supplies heavier GPU-backed models when awake.
