{ inputs, ... }:
{
  # Cody's account. The `user` class forwards to users.users.codyt on every host; the Home
  # Manager profile applies on every host, and per-host extras are
  # delivered by the host aspects (provides.to-users in modules/hosts/<host>.nix).
  den.aspects.codyt = {
    user =
      { pkgs, ... }:
      {
        isNormalUser = true;
        description = "Cody Tucker";
        extraGroups = [
          "networkmanager"
          "wheel"
          "media"
          "scanner"
          "lp"
          "input"
          "documents"
        ];
        shell = pkgs.zsh;
        hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
        openssh = {
          authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkUAtqd1GcKYejbmpxjLzXdMoDojpVuNXEEBhYQjVgY cody@tmvsocial.com"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDS8SglSxSwTUYWOk5takqfqS8HYWhXT2y/AhqtplkAp codyt@nas"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKXcYl6nQLbCQmFihH3DHXFAmmmS5CxcLpYKnSl7EL7b herdr-mobile"
          ];
        };
      };

    # Home Manager profile shared by every host. Features register themselves on every host via
    # den.default (shell, git, nixvim, harness, ...); host-only extras come from the host
    # aspects' provides.to-users.
    homeManager.imports = [
      inputs.nixos-secrets.homeModules.default
    ];
  };
}
