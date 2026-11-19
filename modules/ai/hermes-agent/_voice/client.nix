{
  config,
  lib,
  pkgs,
}:
let
  hermes = import ../_endpoint.nix;
  speech = import ../../llama-swap/_endpoint.nix;
  python = pkgs.python3.withPackages (ps: [ ps.pysilero-vad ]);
in
pkgs.writeShellApplication {
  name = "hermes-waybar-voice";
  runtimeInputs = [
    pkgs.curl
    pkgs.gnused
    pkgs.mpv
    pkgs.pipewire
  ];
  text = ''
    export HERMES_BASE_URL="http://${hermes.host}:${toString hermes.port}"
    export HERMES_SPEECH_BASE_URL="http://${speech.host}:${toString speech.port}"
    # The hermes secret is env-named KEY=value lines; extract API_SERVER_KEY.
    HERMES_API_TOKEN="$(sed -n 's/^API_SERVER_KEY=//p' ${config.sops.secrets."hermes".path})"
    export HERMES_API_TOKEN
    export HERMES_TRANSCRIPTION_MODEL="parakeet-tdt-v3"
    export HERMES_SPEECH_MODEL="kokoro-82m"
    export HERMES_SPEECH_VOICE="af_heart"
    exec ${python}/bin/python ${./hermes-waybar-voice.py} "$@"
  '';
}
