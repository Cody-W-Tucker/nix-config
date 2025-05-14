{ pkgs, ... }:
let
  inherit (pkgs) rnnoise-plugin;
in
{
  # RNNoise configuration
  xdg.configFile."pipewire/pipewire.conf.d/99-rnnoise.conf" = {
    text = builtins.toJSON {
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
                  name = "rnnoise";
                  plugin = "${rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
                  label = "noise_suppressor_mono";
                  control = {
                    "VAD Threshold (%)" = 80.0;
                    "VAD Grace Period (ms)" = 200;
                    "Retroactive VAD Grace (ms)" = 0;
                  };
                }
              ];
            };
            "capture.props" = {
              "node.name" = "capture.rnnoise_source";
              "node.passive" = true;
              "audio.rate" = 48000;
            };
            "playback.props" = {
              "node.name" = "rnnoise_source";
              "media.class" = "Audio/Source";
              "audio.rate" = 48000;
            };
          };
        }
      ];
    };
  };

    # WirePlumber device priorities
  xdg.configFile."wireplumber/main.lua.d/50-device-priorities.lua" = {
    text = ''
      alsa_monitor.rules = {
        {
          matches = {
            { { "node.name", "matches", "alsa_output.usb-Dell_Dell_AC511_USB_SoundBar-00.iec958-stereo" } },
          },
          apply_properties = {
            ["priority.session"] = 100,
            ["api.alsa.use-acp"] = true,
          },
        },
        {
          matches = {
            { { "node.name", "matches", "bluez_output.74_74_46_1C_20_61.1" } },
          },
          apply_properties = {
            ["priority.session"] = 200,
          },
        },
        {
          matches = {
            { { "node.name", "matches", "alsa_output.usb-Blue_Microphones_Yeti_Stereo_Microphone_797_2018_01_30_47703-00.pro-output-0" } },
          },
          apply_properties = {
            ["priority.session"] = 0,
            ["node.disabled"] = true, -- Explicitly disable Yeti output
          },
        },
        {
          matches = {
            { { "node.name", "matches", "alsa_input.usb-Blue_Microphones_Yeti_Stereo_Microphone_797_2018_01_30_47703-00.pro-input-0" } },
          },
          apply_properties = {
            ["priority.session"] = 300,
            ["api.alsa.use-acp"] = true,
          },
        },
        {
          matches = {
            { { "node.name", "matches", "rnnoise_source" } },
          },
          apply_properties = {
            ["priority.session"] = 400,
          },
        },
      }
    '';
  };
}