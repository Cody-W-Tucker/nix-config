{ inputs, ... }:
{
  # Everyday desktop applications and the small user services that go with them. One aspect,
  # `apps`, spans this directory: apps.nix (applications, browsers, Obsidian), terminal.nix
  # (Kitty) and kdeconnect.nix.
  den.aspects.apps.provides.to-users.homeManager =
    { pkgs, ... }:
    let
      # WORKAROUND: Hermes patches patchelf 0.15.2; patchelfUnstable already has the fix.
      # https://github.com/NousResearch/hermes-agent/issues
      # REVIEW-BY: 2026-12-15
      hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        pmPackages = pkgs.lib.filterAttrs (_: pkgs.lib.isDerivation) (
          pkgs.unstable.callPackage "${inputs.hermes-agent}/nix/pm-packages.nix" {
            patchelf = pkgs.unstable.patchelfUnstable // {
              overrideAttrs = _: pkgs.unstable.patchelfUnstable;
            };
          }
        );
      };
      inherit (hermesPackage) hermesDesktop;
    in
    {
      imports = [
        inputs.zen-browser.homeModules.beta
        # Obsidian vault configuration (plugins, hotkeys, snippets); see _obsidian/README.md.
        ./_obsidian
      ];

      programs = {
        # Cursor code editor from spacex SI
        cursor.enable = true;
        zen-browser = {
          enable = true;
          setAsDefaultBrowser = true;
        };
        chromium = {
          enable = true;
          # Chromecast improvement
          commandLineArgs = [ "--load-media-router-component-extension=1" ];
        };
        obs-studio = {
          enable = true;
        };
      };

      services = {
        tailscale-systray.enable = true;

        # Bluetooth AVRCP bridge for MPRIS media controls
        mpris-proxy.enable = true;
      };

      home.packages = with pkgs; [
        inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
        # Hermes Desktop: stay on native Wayland and the NVIDIA hardware path.
        # Vulkan is not compatible with Chromium's native Wayland ozone backend;
        # without this flag, Electron can repeatedly lose its GPU process. Hermes
        # then records that failure and reroutes subsequent launches to CPU-only
        # SwiftShader. Keep that recovery path off after removing Vulkan.
        (
          (hermesDesktop.override {
            extraEnv = {
              ELECTRON_OZONE_PLATFORM_HINT = "wayland";
              HERMES_DESKTOP_NVIDIA_SWIFTSHADER = "0";
            };
          }).overrideAttrs
            (old: {
              postFixup = (old.postFixup or "") + ''
                wrapProgram "$out/bin/hermes-desktop" \
                  --add-flags "--disable-features=Vulkan"
              '';
            })
        )
        # Herdr desktop app; add the NAS under Settings → Machines to see its agents.
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-app
        # Agent memory loop: backpass bundles `acpx` and `lavish-axi` as private
        # runtime dependencies on its own wrapper PATH.
        backpass
        libnotify # Notification library
        nautilus # File manager
        nixd # Nix daemon for development
        gcalcli # Google Calendar CLI tool
        feishin # Desktop app music player
        vesktop # Discord client
        rustdesk-flutter # Remote support into customer machines (public RustDesk servers)
        tuxedo # TUI for tasks
        imagemagick # Image manipulation tools
        libsecret # Secret management library
      ];
    };
}
