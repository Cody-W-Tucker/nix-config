{
  programs = {
    chromium = {
      enable = true;
      # Chromecast improvement
      commandLineArgs = [ "--load-media-router-component-extension=1" ];
    };
    obs-studio = {
      # Obs for screenrecording
      enable = true;
    };
  };
}
