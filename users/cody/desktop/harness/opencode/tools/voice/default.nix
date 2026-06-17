{ ... }:

{
  home.file.".config/opencode/plugins/voice.ts".source = ./plugin.ts;

  home.sessionVariables = {
    OPENCODE_VOICE_TTS_API_URL = "http://127.0.0.1:8081/v1/audio/speech";
    OPENCODE_VOICE_TTS_MODEL = "kokoro-82m";
    OPENCODE_VOICE_TTS_VOICE = "af_heart";
    OPENCODE_VOICE_RECORDING_PID_PATH = "/tmp/llama-dictate-recording.pid";
  };
}
