# Audio, Printing, and Hardware
Relevant source files
- [hosts/beast/models.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/hosts/beast/models.nix)
- [modules/desktop/audio/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix)
- [modules/desktop/gaming/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/gaming/default.nix)
- [modules/desktop/hardware/wifi.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/hardware/wifi.nix)
- [modules/desktop/logging.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/logging.nix)
- [modules/desktop/printing.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/printing.nix)
- [modules/system/strix-hardware/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/default.nix)
- [modules/system/strix-hardware/ec-su-axb35.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ec-su-axb35.nix)
- [modules/system/strix-hardware/ryzenadj.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ryzenadj.nix)
- [modules/system/strix-hardware/tuning.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/tuning.nix)
- [users/cody/desktop/pipewire.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/pipewire.nix)
- [users/home.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/home.nix)

This page details the configuration and management of physical and virtual hardware interfaces within CodyOS. It covers the audio subsystem powered by PipeWire, printing services via CUPS, gaming-specific optimizations, and specialized hardware tuning for AMD Strix Halo platforms.

## Audio Subsystem

The audio stack is built on **PipeWire**, providing a modern replacement for PulseAudio and JACK with high-performance routing and low-latency capabilities [modules/desktop/audio/default.nix4-9](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix#L4-L9)

### PipeWire and Bluetooth Configuration

The system enables ALSA (including 32-bit support for legacy applications and games) and PulseAudio emulation [modules/desktop/audio/default.nix6-8](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix#L6-L8) Bluetooth audio is specifically tuned to prevent automatic switching to low-quality headset profiles, forcing high-quality A2DP with the AAC codec [modules/desktop/audio/default.nix12-26](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix#L12-L26)

| Feature | Configuration Detail | File |
| --- | --- | --- |
| **Backends** | ALSA, PulseAudio, WirePlumber | [modules/desktop/audio/default.nix4-10](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix#L4-L10) |
| **Bluetooth Codecs** | AAC (High Quality mode) | [modules/desktop/audio/default.nix21-25](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix#L21-L25) |
| **Repairing** | JustWorksRepairing = "always" | [modules/desktop/audio/default.nix62](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix#L62-L62) |
| **Controller** | BR/EDR mode enabled | [modules/desktop/audio/default.nix60](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix#L60-L60) |

### Noise Cancellation (RNNoise)

For improved voice input (critical for the `hermes-voice` AI interface), the system implements a `filter-chain` module using `librnnoise_ladspa`[users/cody/desktop/pipewire.nix8-22](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/pipewire.nix#L8-L22) This creates a virtual "Noise Canceling source" with a VAD (Voice Activity Detection) threshold of 80% [users/cody/desktop/pipewire.nix14-24](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/pipewire.nix#L14-L24)

**Audio Data Flow and Code Entities**

```

```

Sources: [modules/desktop/audio/default.nix4-53](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/audio/default.nix#L4-L53)[users/cody/desktop/pipewire.nix8-45](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/pipewire.nix#L8-L45)

## Printing and Discovery

Printing is handled by **CUPS** (Common Unix Printing System) with **Avahi** enabled for network printer discovery via mDNS/DNS-SD [modules/desktop/printing.nix3-10](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/printing.nix#L3-L10)

- **Drivers**: Includes `cups-filters`, `cups-browsed`, and specialized `canon-cups-ufr2` drivers [modules/desktop/printing.nix11-15](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/printing.nix#L11-L15)
- **Network**: Avahi is configured to open the firewall and enable `nssmdns4` for `.local` hostname resolution [modules/desktop/printing.nix5-7](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/printing.nix#L5-L7)

Sources: [modules/desktop/printing.nix1-17](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/printing.nix#L1-L17)

## Gaming and Graphics

Gaming support is optimized through the `programs.steam` module and performance-oriented system tweaks [modules/desktop/gaming/default.nix8-10](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/gaming/default.nix#L8-L10)

- **Steam**: Enabled with `gamescopeSession` support for optimized Wayland compositing [modules/desktop/gaming/default.nix9-12](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/gaming/default.nix#L9-L12)
- **Performance**: The system forces the `performance` CPU frequency governor and enables `gamemode` for on-demand resource prioritization [modules/desktop/gaming/default.nix13-23](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/gaming/default.nix#L13-L23)
- **Compatibility**: 32-bit OpenGL support is enabled via `hardware.graphics.enable32Bit` to ensure compatibility with older titles [modules/desktop/gaming/default.nix5](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/gaming/default.nix#L5-L5)
- **Packages**: Includes `prismlauncher` for Minecraft and `gamescope-wsi`[modules/desktop/gaming/default.nix17-20](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/gaming/default.nix#L17-L20)

Sources: [modules/desktop/gaming/default.nix1-24](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/desktop/gaming/default.nix#L1-L24)

## Strix Halo Hardware Tuning

CodyOS includes sophisticated modules for tuning AMD Strix Halo (Ryzen AI MAX+) hardware, specifically targeting the GMKtec EVO-X2 and similar platforms [modules/system/strix-hardware/default.nix1-9](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/default.nix#L1-L9)

### RyzenAdj Power Management

The `ryzenadj` module allows declarative control over AMD mobile/APU power limits and the Curve Optimizer [modules/system/strix-hardware/ryzenadj.nix130-131](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ryzenadj.nix#L130-L131)

- **Power Limits**: Configures `stapmLimit` (Sustained), `fastLimit` (PPT Fast), and `slowLimit` (PPT Slow) in milliwatts [modules/system/strix-hardware/ryzenadj.nix133-152](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ryzenadj.nix#L133-L152)
- **Curve Optimizer**: Supports undervolting with a safety `graceSeconds` delay to allow system recovery if settings are unstable [modules/system/strix-hardware/ryzenadj.nix194-209](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ryzenadj.nix#L194-L209)
- **Verification**: The `ryzenadj-config` script parses `ryzenadj -i` output to verify that limits were successfully applied to the hardware [modules/system/strix-hardware/ryzenadj.nix101-112](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ryzenadj.nix#L101-L112)

### EC-SU_AXB35 Embedded Controller

For the GMKtec EVO-X2, a custom module manages the `ec_su_axb35` embedded controller for fan and thermal control [modules/system/strix-hardware/ec-su-axb35.nix1-10](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ec-su-axb35.nix#L1-L10)

- **Fan Control**: Supports three fans (`fan1`, `fan2`, `fan3`) with modes for `auto`, `fixed`, or `curve`[modules/system/strix-hardware/ec-su-axb35.nix127-145](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ec-su-axb35.nix#L127-L145)
- **Thermal Curves**: Allows defining `rampupCurve` and `rampdownCurve` temperature thresholds [modules/system/strix-hardware/ec-su-axb35.nix37-49](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ec-su-axb35.nix#L37-L49)
- **Power Modes**: Sets the APU power mode to `quiet`, `balanced`, or `performance` via sysfs [modules/system/strix-hardware/ec-su-axb35.nix115-125](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ec-su-axb35.nix#L115-L125)

**Hardware Tuning Entity Mapping**

```

```

Sources: [modules/system/strix-hardware/ryzenadj.nix94-125](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ryzenadj.nix#L94-L125)[modules/system/strix-hardware/ec-su-axb35.nix75-99](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ec-su-axb35.nix#L75-L99)[modules/system/strix-hardware/tuning.nix5-15](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/tuning.nix#L5-L15)

### Performance Profiles (TuneD)

The `tuning.nix` module leverages the `tuned` daemon to apply the `accelerator-performance` profile, optimizing the system for AI and heavy compute workloads [modules/system/strix-hardware/tuning.nix5-14](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/tuning.nix#L5-L14)

Sources: [modules/system/strix-hardware/ryzenadj.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ryzenadj.nix)[modules/system/strix-hardware/ec-su-axb35.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/ec-su-axb35.nix)[modules/system/strix-hardware/tuning.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/strix-hardware/tuning.nix)