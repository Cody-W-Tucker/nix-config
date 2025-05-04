{inputs, pkgs, ...}:

# This is a home-manager config module
{
  imports = [
    inputs.whisper-overlay.homeManagerModules.default
  ];

  # Also make sure to enable cuda support in nixpkgs, otherwise transcription will
  # be painfully slow. But be prepared to let your computer build packages for 2-3 hours.
  nixpkgs.config.cudaSupport = true;

  # Enable the user service
  services.realtime-stt-server.enable = true;
  # If you want to automatically start the service with your graphical session,
  # enable this too. If you want to start and stop the service on demand to save
  # resources, don't enable this and use `systemctl --user <start|stop> realtime-stt-server`.
  services.realtime-stt-server.autoStart = true;

  # Add the whisper-overlay package so you can start it manually.
  # Alternatively add it to the autostart of your display environment or window manager.
  home.packages = [ pkgs.whisper-overlay ];
}