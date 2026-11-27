{
  den,
  inputs,
  ...
}:
{
  den.aspects.beast.includes = [ den.aspects.apps ];

  den.aspects.apps = {
    includes = [ den.aspects.google-workspace.desktop ];
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

        programs = {
          cursor.enable = true;
          zen-browser = {
            enable = true;
            setAsDefaultBrowser = true;
          };
          chromium = {
            enable = true;
            commandLineArgs = [ "--load-media-router-component-extension=1" ];
          };
          obs-studio = {
            enable = true;
          };
        };

        services = {
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
        ];
      };
  };
}
