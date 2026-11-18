{ pkgs, ... }:
let
  inherit (pkgs) deepfilternet;
  ladspaPath = "${deepfilternet}/lib/ladspa";
in
{
  # DeepFilterNet denoising source
  xdg.configFile."pipewire/pipewire.conf.d/99-deepfilter.conf" = {
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
                  name = "deepfilter";
                  plugin = "libdeep_filter_ladspa";
                  label = "deep_filter_mono";
                  control = {
                    "Attenuation Limit (dB)" = 100.0;
                  };
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
  };

  xdg.configFile."systemd/user/pipewire.service.d/zz-deepfilter.conf".text = ''
    [Service]
    Environment="LADSPA_PATH=${ladspaPath}"
  '';
}
