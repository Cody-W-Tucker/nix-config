{
  config,
  inputs,
  pkgs,
  ...
}:

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
    firefox = {
      # Zen browser via Firefox module
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
      # Replace firefox with zen browser to use home manager module
      package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
      profiles.default = {
        # hardware acceleration settings
        settings = {
          # Enable VA-API video decoding
          "media.ffmpeg.vaapi.enabled" = true;
          # Enable hardware decoding
          "media.hardware-video-decoding.enabled" = true;
          # Enable WebRender for better GPU acceleration
          "gfx.webrender.all" = true;
          "gfx.webrender.enabled" = true;
          # Additional video-path settings
          "media.ffmpeg.dmabuf-textures.enabled" = true;
          "media.rdd-ffmpeg.enabled" = true;
          # Disable software fallback for video decoding
          "media.decoder-doctor.notifications-allowed" = false;
        };
      };
    };
  };
}
