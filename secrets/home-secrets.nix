{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    # This will automatically import SSH keys as age keys
    age.sshKeyPaths = [ "/home/codyt/.ssh/id_ed25519" ];
    # This will generate a new key if the key specified above does not exist
    age.generateKey = true;
    gnupg.sshKeyPaths = [ ];
  };
}
