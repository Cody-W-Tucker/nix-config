# User accounts and groups configuration

{ pkgs, ... }:

{
  # Make passwords uneditable
  users = {
    mutableUsers = false;
    users.codyt = {
      isNormalUser = true;
      description = "Cody Tucker";
      extraGroups = [
        "networkmanager"
        "wheel"
        "media"
        "scanner"
        "lp"
        "bluetooth"
        "input"
        "documents"
      ];
      shell = pkgs.zsh;
      hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
      openssh = {
        authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkUAtqd1GcKYejbmpxjLzXdMoDojpVuNXEEBhYQjVgY cody@tmvsocial.com"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmuJot98ty1ToPLarWkw2gwNbYMltdREaiUPuDQbTC9 codyt@nas"
        ];
      };
    };
    groups.media = { };
    groups.documents = { };
  };

  systemd.tmpfiles.rules = [
    # Pre-create borgbackup directories to avoid duplicate tmpfiles warnings
    "d /home/codyt/.cache 0755 codyt users - -"
    "d /home/codyt/.cache/borg 0755 codyt users - -"
    "d /home/codyt/.config 0755 codyt users - -"
    "d /home/codyt/.config/borg 0755 codyt users - -"
  ];
}
