{
  den,
  inputs,
  ...
}:
{
  den.aspects.beast.includes = [ den.aspects.apps ];

  den.aspects.apps = {
    includes = [ den.aspects.google-workspace.desktop ];
    nixos.networking.firewall =
      let
        kdeConnectPorts = [
          {
            from = 1714;
            to = 1764;
          }
        ];
      in
      {
        allowedTCPPortRanges = kdeConnectPorts;
        allowedUDPPortRanges = kdeConnectPorts;
      };
    provides.to-users.homeManager =
      { pkgs, ... }:
      let
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
        codyos.workarounds.hermes-desktop-patchelf = {
          reason = "Hermes's pm-packages backport a patch onto patchelf 0.15.2; hermesPackage swaps in patchelfUnstable, which already has the fix.";
          upstream = "https://github.com/NousResearch/hermes-agent/pull/152542";
          reviewBy = "2027-01-15";
        };

        imports = [
          inputs.zen-browser.homeModules.beta
          ./_obsidian
        ];

        home.sessionVariables.TERMINAL = "kitty";

        programs = {
          zsh.shellAliases = {
            ssh- = "kitty +kitten ssh";
            copy = "kitten clipboard";
          };
          kitty = {
            enable = true;
            settings = {
              remember_window_size = "no";
              auto_reload_config = "-1";
              shell_integration = "no-cursor";
              window_padding_width = "0 8";
              confirm_os_window_close = "0";
              wayland_titlebar_color = "system";
              cursor_shape = "block";
              enable_audio_bell = "no";
              cursor_trail = 1;
              cursor_trail_start_threshold = 3;
              cursor_trail_decay = "0.1 0.4";
              tab_bar_style = "powerline";
            };
          };
          cursor.enable = true;
          zen-browser = {
            enable = true;
            setAsDefaultBrowser = true;
          };
          chromium = {
            enable = true;
            commandLineArgs = [ "--load-media-router-component-extension=1" ];
          };
          obs-studio.enable = true;
        };

        services = {
          kdeconnect = {
            enable = true;
            indicator = true;
          };
          tailscale-systray.enable = true;
          mpris-proxy.enable = true;
        };

        home.packages = with pkgs; [
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
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-app
          backpass
          libnotify
          nautilus
          nixd
          gcalcli
          feishin
          vesktop
          rustdesk-flutter
          tuxedo
          imagemagick
          libsecret
          kdePackages.kpeople
        ];
      };
  };
}
