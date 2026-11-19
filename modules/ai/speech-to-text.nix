{
  # llama-dictate: push-to-talk dictation against the NAS llama-swap speech endpoints
  # (modules/ai/llama-swap/). The user-side client; included by the workstation (beast).
  den.aspects.speech-to-text.provides.to-users.homeManager.imports = [ ./_speech-to-text.nix ];
}
