{ pkgs, ... }:

{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber = {
      enable = true;
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
            "bluez5.codecs" = [
              "sbc_xq"
              "sbc"
              "aac"
            ];
            "bluez5.enable-sbc-xq" = true;
            "bluez5.hfphsp-backend" = "native";
            "bluez5.a2dp.ldac.quality" = "hq";
            "bluez5.a2dp.aac.bitratemode" = "hq";
          };
        };
        "bluetooth-seat-monitoring" = {
          "wireplumber.profiles" = {
            main = {
              "monitor.bluez.seat-monitoring" = "disabled";
            };
          };
        };
        "bluetooth-device-profile" = {
          "monitor.bluez.rules" = [
            {
              matches = [
                {
                  "device.name" = "~bluez_card.*";
                }
              ];
              actions.update-props = {
                "device.profile" = "a2dp-sink";
              };
            }
          ];
        };
      };
    };
  };

  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "bredr";
        FastConnectable = true;
        JustWorksRepairing = "always";
        MultiProfile = "multiple";
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    pbpctrl
  ];
}
