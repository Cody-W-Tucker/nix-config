{
  # Browser and recording apps: Chromium (Chromecast flag) and OBS Studio.
  den.aspects.programs = {
    provides.to-users.homeManager = {
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
    };
  };
}
