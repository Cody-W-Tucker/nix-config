{
  imports = [
    ./ui
    ./cli
  ];

  # Keyboard
  home.keyboard = {
    layout = "us";
    model = "pc105";
  };
  # Set the wallpaper
  stylix.image = ../modules/wallpapers/galaxy-waves.jpg;

  home.sessionVariables.CUDA_CACHE_PATH = "\${HOME}/.cache/nv";

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "24.05";
}
