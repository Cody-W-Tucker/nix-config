{ pkgs, ... }:

{
  sops.defaultSopsFile = ./secrets.yaml;

  # This will automatically import SSH keys as age keys
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  # This is using an age key that is expected to already be in the filesystem
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  # This will generate a new key if the key specified above does not exist
  sops.age.generateKey = true;
  sops.gnupg.sshKeyPaths = [ ];

  environment.systemPackages = [ pkgs.sops ];
}
