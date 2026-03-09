{
  inputs,
  hardwareConfig ? { },
  ...
}:

{
  imports = [ inputs.whisp-away.nixosModules.home-manager ];
  services.whisp-away = {
    enable = hardwareConfig.enableWhisp or true;
    defaultModel = "base.en";
    defaultBackend = "whisper-cpp";
    # Use acceleration from hardware config, fallback to CPU for fast builds
    accelerationType = hardwareConfig.whispAcceleration or "cpu";
    useClipboard = false;
    useCrane = false;
  };
}
