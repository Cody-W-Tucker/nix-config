{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.audio ];

  den.aspects.audio = {
    nixos =
      { pkgs, ... }:
      {
        services.pipewire = {
          enable = true;
          alsa = {
            enable = true;
            support32Bit = true;
          };
          pulse.enable = true;
          wireplumber = {
            extraConfig = {
              "bluetooth" = {
                "wireplumber.settings" = {
                  "bluetooth.autoswitch-to-headset-profile" = false;
                };
                "monitor.bluez.properties" = {
                  "bluez5.roles" = [
                    "a2dp_sink"
                    "a2dp_source"
                  ];
                  "bluez5.codecs" = [ "aac" ];
                  "bluez5.hfphsp-backend" = "native";
                  "bluez5.a2dp.aac.bitratemode" = "hq";
                };
              };
              "bluetooth-seat-monitoring" = {
                "wireplumber.profiles".main."monitor.bluez.seat-monitoring" = "disabled";
              };
              "bluetooth-device-profile" = {
                "monitor.bluez.rules" = [
                  {
                    matches = [ { "device.name" = "~bluez_card.*"; } ];
                    actions.update-props."device.profile" = "a2dp-sink";
                  }
                ];
              };
            };
          };
        };

        security.rtkit.enable = true;

        hardware.bluetooth = {
          enable = true;
          settings.General = {
            ControllerMode = "bredr";
            FastConnectable = true;
            JustWorksRepairing = "always";
            MultiProfile = "multiple";
          };
        };

        services.blueman.enable = true;

        environment.systemPackages = [ pkgs.pbpctrl ];
      };
    provides.to-users.homeManager =
      { pkgs, ... }:
      let
        ladspaPath = "${pkgs.deepfilternet}/lib/ladspa";
      in
      {
        xdg.configFile."pipewire/pipewire.conf.d/99-deepfilter.conf".text = builtins.toJSON {
          "context.modules" = [
            {
              name = "libpipewire-module-filter-chain";
              args = {
                "node.description" = "Noise Canceling source";
                "media.name" = "Noise Canceling source";
                "filter.graph" = {
                  nodes = [
                    {
                      type = "ladspa";
                      name = "deepfilter";
                      plugin = "libdeep_filter_ladspa";
                      label = "deep_filter_mono";
                      control."Attenuation Limit (dB)" = 100.0;
                    }
                  ];
                };
                "capture.props" = {
                  "node.name" = "capture.deepfilter_source";
                  "node.passive" = true;
                  "audio.rate" = 48000;
                  "audio.position" = [ "MONO" ];
                };
                "playback.props" = {
                  "node.name" = "deepfilter_source";
                  "media.class" = "Audio/Source";
                  "audio.rate" = 48000;
                  "audio.position" = [ "MONO" ];
                };
              };
            }
          ];
        };

        xdg.configFile."systemd/user/pipewire.service.d/zz-deepfilter.conf".text = ''
          [Service]
          Environment="LADSPA_PATH=${ladspaPath}"
        '';
      };
  };
}
