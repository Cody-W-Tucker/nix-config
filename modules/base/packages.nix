{
  # Base system packages.
  den.aspects.packages.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        git
        btop
        wget
      ];
    };
}
