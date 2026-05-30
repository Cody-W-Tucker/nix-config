{
  inputs,
  home-manager-input,
  ...
}:

{
  # Cap coredump storage so /var/lib/systemd/coredump does not balloon.
  systemd.coredump.settings = {
    Coredump.MaxUse = "500M";
    Coredump.KeepFree = "2G";
    Coredump.ProcessSizeMax = "100M";
  };

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
