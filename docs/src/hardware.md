# Sound, printing, gaming and hardware

The smaller pieces of beast's desk setup.

| For | Do |
| --- | --- |
| Calls without background noise | Select the **Noise Canceling source** microphone |
| A Bluetooth headset on a call | Switch its profile in sound settings; headsets stay in music mode until you do |
| Bluetooth pairing | Blueman (Bluetooth Low Energy-only devices may not pair) |
| Printing | Canon UFR II printers; network printers are discovered |
| Games | Steam (GameMode, gamescope), Prism Launcher (Minecraft) |
| Razer lighting | Open Polychromatic; its tray icon does not start at login. Lighting stays on when the screen blanks. |
| A new project | `project new <template> <dir>`, `project init <template>`, `project help`. Then `direnv allow`. |

The CPU runs at full performance at all times. Docker prunes unused data weekly (also on the NAS). Wake-on-LAN is off while beast is on Wi-Fi; `git revert 922f8ac4` restores it.

## Changing it

| To change | Edit |
| --- | --- |
| Sound, Bluetooth audio | [`audio.nix`](../../modules/audio.nix) |
| Printing | [`printing.nix`](../../modules/printing.nix) |
| Games | [`gaming.nix`](../../modules/gaming.nix) |
| NVIDIA driver (both hosts) | [`nvidia.nix`](../../modules/hardware/nvidia.nix) |
| Razer | [`openrazer.nix`](../../modules/hardware/openrazer.nix) |
| Docker (both hosts) | [`docker.nix`](../../modules/containers/docker.nix) |
| `project` templates | [`_scripts/project.nix`](../../modules/development/_scripts/project.nix) |
