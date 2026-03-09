# User accounts and groups configuration

{ pkgs, ... }:

{
  # Make passwords uneditable
  users.mutableUsers = false;

  users.users.codyt = {
    isNormalUser = true;
    description = "Cody Tucker";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "media"
      "scanner"
      "lp"
      "bluetooth"
      "input"
      "documents"
      "openrazer"
    ];
    shell = pkgs.zsh;
    hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
    openssh = {
      authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkUAtqd1GcKYejbmpxjLzXdMoDojpVuNXEEBhYQjVgY cody@tmvsocial.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ0Ct+Iccmg3sne63r8bM/W47fEktUsUm8zkseKXwqzz" # aiserver
      ];
    };
  };

  # Create user groups for different services
  users.groups.media = { };
  users.groups.documents = { };

  # Pre-create borgbackup directories to avoid duplicate tmpfiles warnings
  systemd.tmpfiles.rules = [
    "d /home/codyt/.cache 0755 codyt users - -"
    "d /home/codyt/.cache/borg 0755 codyt users - -"
    "d /home/codyt/.config 0755 codyt users - -"
    "d /home/codyt/.config/borg 0755 codyt users - -"
  ];
}
