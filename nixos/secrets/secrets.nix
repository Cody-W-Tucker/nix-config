{ pkgs, inputs, config, ... }:

{
  sops.defaultSopsFile = ./secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  sops.age.keyFile = "/home/codyt/.config/sops/age/keys.txt";

  environment.systemPackages = with pkgs; [
    sops
  ];
}
