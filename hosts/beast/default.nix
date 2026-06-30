{
  imports = [
    ./ai.nix
    ./models.nix
  ];

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };
}
