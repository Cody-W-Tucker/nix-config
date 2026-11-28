{ den, ... }:
{
  den.aspects.graphical = {
    includes = [ den.aspects.hermes-voice-client ];

    nixos =
      { config, lib, ... }:
      let
        session = {
          command = "${lib.getExe config.programs.uwsm.package} start hyprland.desktop";
          user = config.codyos.site.user.name;
        };
      in
      {
        programs.hyprland = {
          enable = true;
          withUWSM = true;
        };

        security.pam.services = {
          hyprlock.enableGnomeKeyring = true;
          greetd.enableGnomeKeyring = true;
          login.enableGnomeKeyring = true;
        };

        services.greetd = {
          enable = true;
          settings = {
            terminal.vt = 1;
            initial_session = session;
            default_session = session;
          };
        };
      };

    provides.to-users.homeManager =
      {
        host,
        pkgs,
        lib,
        config,
        ...
      }:
      let
        inherit (host) hardwareConfig;
        lock = "${pkgs.systemd}/bin/loginctl lock-session";
        dpms = action: ''hyprctl dispatch 'hl.dsp.dpms({action = "${action}"})''\''';
      in
      {
        imports = [
          (import ./_hyprland/settings.nix { inherit hardwareConfig; })
          ./_waybar/waybar.nix
        ];

        home.packages = with pkgs; [
          wttrbar
          playerctl
          wl-clipboard
          (hyprnome.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./_hyprland/hyprnome-lua-config-provider.patch ];
          }))
        ];

        xdg.configFile."uwsm/env".source =
          "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

        wayland.windowManager.hyprland = {
          enable = true;
          package = null;
          portalPackage = null;
          systemd.enable = false;
          configType = "lua";
        };

        services = {
          cliphist = {
            enable = true;
            allowImages = true;
            extraOptions = [
              "-max-dedupe-search"
              "10"
              "-max-items"
              "50"
            ];
          };

          hyprpolkitagent.enable = true;
          gnome-keyring = {
            enable = true;
            components = [
              "secrets"
              "ssh"
            ];
          };

          hypridle = {
            enable = true;
            settings = {
              general = {
                before_sleep_cmd = lock;
                after_sleep_cmd = dpms "enable";
                lock_cmd = "pgrep hyprlock || ${lib.getExe config.programs.hyprlock.package}";
              };

              listener = [
                {
                  timeout = 900;
                  on-timeout = lock;
                }
                {
                  timeout = 1800;
                  on-timeout = dpms "disable";
                  on-resume = dpms "enable";
                }
              ]
              ++ lib.optional (hardwareConfig.hypridle.suspendTimeout != null) {
                timeout = hardwareConfig.hypridle.suspendTimeout;
                on-timeout = "systemctl suspend";
              };
            };
          };
        };

        programs.hyprlock = {
          enable = true;
          settings = {
            general = {
              hide_cursor = true;
              ignore_empty_input = true;
            };
            background = [
              {
                monitor = "";
                path = "screenshot";
                color = "rgba(25, 20, 20, 1.0)";
                blur_passes = 2;
                blur_size = 2;
                noise = 0.0117;
                contrast = 0.8916;
                brightness = 0.8172;
                vibrancy = 0.1696;
                vibrancy_darkness = 0.0;
              }
            ];
            input-field = [
              {
                size = "200, 50";
                outline_thickness = 3;
                dots_size = 0.33;
                dots_spacing = 0.15;
                dots_center = false;
                dots_rounding = -1;
                outer_color = "rgb(151515)";
                inner_color = "rgb(200, 200, 200)";
                font_color = "rgb(10, 10, 10)";
                fade_on_empty = true;
                fade_timeout = 1000;
                placeholder_text = "<i>Input Password...</i>";
                hide_input = false;
                rounding = -1;
                check_color = "rgb(204, 136, 34)";
                fail_color = "rgb(204, 34, 34)";
                fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
                capslock_color = -1;
                numlock_color = -1;
                bothlock_color = -1;
                invert_numlock = false;
                swap_font_color = false;
              }
            ];
          };
        };
      };
  };
}
