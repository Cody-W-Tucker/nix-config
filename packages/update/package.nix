{
  writeShellApplication,
  nix,
  git,
  nixos-rebuild,
  check-imports,
  openssh,
}:

writeShellApplication {
  name = "update";
  runtimeInputs = [
    nix
    git
    nixos-rebuild
    check-imports
    openssh
  ];
  text = builtins.readFile ./update.sh;
}
