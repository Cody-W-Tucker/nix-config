{
  inputs,
  home-manager-input,
  ...
}:

{
  # Cap coredump storage so /var/lib/systemd/coredump does not balloon.
  systemd.coredump.extraConfig = ''
    MaxUse=500M
    KeepFree=2G
    ProcessSizeMax=100M
  '';

  imports = [
    inputs.sops-nix.nixosModules.sops
    home-manager-input.nixosModules.home-manager
    ../../packages/system-scripts
    ./locale.nix
    ./nix.nix
    ./users.nix
    ./fonts.nix
    ./packages.nix
    ./shell.nix
    ./services.nix
    ./networking.nix
    ../../secrets/secrets.nix
    ../../users/home.nix
  ];
}
