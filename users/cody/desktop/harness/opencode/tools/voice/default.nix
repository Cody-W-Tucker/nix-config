{ config, lib, ... }:

let
  pluginPath = "${config.xdg.configHome}/opencode/plugins/voice.ts";
in

{
  home.activation.opencodeVoicePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    plugin_dir="${config.xdg.configHome}/opencode/plugins"

    mkdir -p "$plugin_dir"
    cp ${./plugin.ts} "$plugin_dir/voice.ts"
    chmod u+w "$plugin_dir/voice.ts"
  '';

  programs.opencode.settings.plugin = [ pluginPath ];

  home.sessionVariables = {
    OPENCODE_VOICE_TTS_API_URL = "http://127.0.0.1:8081/v1/audio/speech";
    OPENCODE_VOICE_TTS_MODEL = "kokoro-82m";
    OPENCODE_VOICE_TTS_VOICE = "af_heart";
    OPENCODE_VOICE_RECORDING_PID_PATH = "/tmp/llama-dictate-recording.pid";
  };
}
