{ den, inputs, ... }:
{
  # Cody's account. The `user` class forwards to users.users.codyt on every host; the Home
  # Manager profile applies on every host, and the role (desktop/server), editor and
  # per-host extras are delivered by the host aspects (provides.to-users in
  # modules/hosts/<host>.nix).
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

    # Home Manager profile shared by every host: shell, git, CLI tools, editor and the
    # AI/operator harness. Role-specific content (desktop, server) and host-only extras
    # come from the host aspects' provides.to-users.
    includes = [
      den.aspects.user-shell
      den.aspects.user-git
      den.aspects.user-cli-tools
      den.aspects.nixvim
      den.aspects.harness
    ];

    homeManager.imports = [
      inputs.nixos-secrets.homeModules.default
    ];
  };
}
