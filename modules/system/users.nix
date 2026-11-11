# User accounts and groups configuration

{ config, pkgs, ... }:

let
  inherit (config.codyos.site) user;
in

{
  # Make passwords uneditable
  users = {
    mutableUsers = false;
    users.${user.name} = {
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
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDS8SglSxSwTUYWOk5takqfqS8HYWhXT2y/AhqtplkAp codyt@nas"
        ];
      };
    };
    groups.media = { };
    groups.documents = { };
  };

  systemd.tmpfiles.rules = [
    # Pre-create borgbackup directories to avoid duplicate tmpfiles warnings
    "d ${user.home}/.cache 0755 ${user.name} users - -"
    "d ${user.home}/.cache/borg 0755 ${user.name} users - -"
    "d ${user.home}/.config 0755 ${user.name} users - -"
    "d ${user.home}/.config/borg 0755 ${user.name} users - -"
  ];
}
