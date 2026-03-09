{ inputs, ... }:

{
  imports = [ inputs.whisp-away.nixosModules.home-manager ];

  services.whisp-away = {
    enable = true;
    defaultModel = "base.en"; # Default model (changes apply immediately)
    defaultBackend = "faster-whisper"; # Backend selection (changes apply immediately)
    accelerationType = "vulkan"; # or "cuda", "openvino", "cpu" - requires rebuild
    useClipboard = false; # Output mode (changes apply immediately)
    useCrane = false; # Enable if you want faster rebuilds when developing
  };
}
