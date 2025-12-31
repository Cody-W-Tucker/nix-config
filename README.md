# Instructions for new machine

Install via the NixOS installer, configure drives etc. to build a default config. Then to add to the share config...

1. Edit the configuration.nix file to
   1. Enable SSH
   2. Install git
   3. Install kitty (to use system clipboard)
   4. Set the hostname of the new machine

Rebuild the config with the new hostname and then connect via ssh.

1. ssh-copy-id to the new machine
2. scp the parent config to the child computer's homedir
3. mv the child's config to `/etc/nixos-aside`
4. mv the parent config to `/etc/nixos`
5. cp `nixos-aside` to `/etc/nixos/hosts`
6. git add, commit, and push (to work on parent environment)
7. Concat the hardware and config files into one host file. (follow the parent pattern, ensure the drives are correct)
8. Commit the change and pull/rebuild on the child machine

Configure the machine to get secrets

1. Create a public key for the new machine via SOPS-NIX instructions
2. Add the Public key to the .sops.yaml file
3. sops updatekeys secrets.yaml

# Thoughts

I could use hardware-configuration instead of putting everything into the machine host file. Then when hardware changes it's easier regenerate the configuration.
