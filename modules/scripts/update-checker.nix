{ pkgs }:

pkgs.writeShellScriptBin "update-checker" ''
  #!/usr/bin/env bash

  #This script assumes your flake is in /etc/nixos and that your flake's nixosConfigurations is named the same as your $hostname
  updates="$(cd /etc/nixos && nix flake lock nixpkgs && nix build .#nixosConfigurations.$HOSTNAME.config.system.build.toplevel && nvd diff /run/current-system ./result | grep -e '\[U' | wc -l)"

  alt="has-updates"
  if [ $updates -eq 0 ]; then
      alt="updated"
  fi

  tooltip="System updated"
  if [ $updates != 0 ]; then
  	tooltip=$(cd /etc/nixos && nvd diff /run/current-system ./result | grep -e '\[U' | awk '{ for (i=3; i<NF; i++) printf $i " "; if (NF >= 3) print $NF; }' ORS='\\n' )
  fi

  echo "{ \"text\":\"$updates\", \"alt\":\"$alt\", \"tooltip\":\"$tooltip\" }"
''
