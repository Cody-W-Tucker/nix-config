# Beast Desktop Workstation

`beast` is the primary high-performance CodyOS desktop. This directory owns the host-specific detail for hardware, storage, local AI services, and desktop tuning.

Central docs should point here instead of duplicating this host map.

## Layout

| Path | Role |
| --- | --- |
| `default.nix` | Host import spine. |
| `machine.nix` | Machine identity, kernel choice, monitor/workspace hints, and hardware metadata. |
| `drives.nix` | Local disks, bind mounts, NFS mounts, Btrfs work pool, and storage maintenance. |
| `models.nix` | Local `llama-swap` model catalog and acceleration settings. |
| `ai.nix` | Open-WebUI, Qdrant, and AI-supporting services. |

Shared modules used heavily by this host include `modules/desktop/hardware/nvidia.nix`, `modules/desktop/audio/default.nix`, and the `modules/services/llama-swap/` wrappers.

## Hardware profile

| Component | Configuration |
| --- | --- |
| CPU | Intel Core i9-14900KF, 24 cores / 32 threads. |
| GPU | NVIDIA RTX 3070, 8GB VRAM. |
| RAM | 64GB DDR5. |
| Storage | 2TB NVMe root plus two 1TB NVMe drives for the work pool. |
| Kernel | Latest Linux kernel via `pkgs.linuxPackages_latest`. |

The host is tuned for local AI inference, software development, 4K/high-refresh desktop use, and gaming.

## Graphics and CUDA

The NVIDIA stack is configured for Wayland desktop use and CUDA workloads.

- The production NVIDIA driver is used with the open kernel module enabled.
- `nvidia-uvm` is loaded for CUDA unified memory support.
- GBM is set to the NVIDIA DRM backend for Wayland buffer handling.
- Electron flags enable Wayland DRM sync object and VA-API video decode behavior expected by this setup.
- Firefox/Zen hardware acceleration is supported with the required NVIDIA VA-API sandbox workaround.
- Global CUDA support is enabled, with the `nixos-cuda` cache configured to avoid unnecessary local builds.

## Storage topology

`drives.nix` defines the storage layout.

- `/` is ext4 on the 2TB NVMe.
- `/mnt/work` is a Btrfs pool across the two 1TB NVMe drives.
- `/mnt/work/vm` and `/mnt/work/cache` get NoCoW via the `work-btrfs-nocow` service for VM images and model/cache-heavy workloads.
- Btrfs scrub runs monthly.
- Standard user media/document directories are bind-mounted from the local backup share to stay aligned with Syncthing flows.
- Server media/books are mounted over NFS with systemd automounts for on-demand access.

## AI stack

Beast hosts the primary local AI stack.

- `services.llama-swap` runs with CUDA acceleration.
- The model catalog includes reasoning/summarization, OCR/vision, and an audio stack.
- Whisper STT and Kokoro TTS are kept warm for low-latency voice interaction.
- Open-WebUI runs locally for model interaction and RAG workflows.
- Qdrant is enabled with persistent on-disk HNSW indexing.
- Open-WebUI is wired to Qdrant and an external Tika server for document extraction.

The Python wrappers under `modules/services/llama-swap/` provide OpenAI-compatible endpoints for speech and related model services.

## Desktop and hardware abstraction

`machine.nix` passes host-specific `hardwareConfig` into the desktop layer.

Current desktop assumptions:

- Primary monitor is `DP-1` at 2560x1440, high refresh, VRR, and 10-bit color.
- Workspace 1 is assigned to the primary monitor.
- Hypridle suspend timeout is two hours.

Audio and Bluetooth come from the shared desktop audio module:

- PipeWire is configured with high-quality AAC Bluetooth support.
- Seat monitoring is disabled to reduce Bluetooth connection drops.
- Bluetooth uses `bredr` mode with `JustWorksRepairing` enabled.
- `btusb` kernel parameters disable autosuspend and allow resets for flaky controllers.

## Operator notes

- Keep host-specific operational detail in this README.
- Put reusable behavior in shared modules and document it there when it stops being Beast-specific.
- Add new files to git before expecting flakes to see them.
- For risky host changes, test with `nixos-rebuild dry-run --flake .#beast` from `/etc/nixos`. Doc-only edits do not need a build.
