{ den, inputs, ... }:
{
  # Cody's account. The `user` class forwards to users.users.codyt on every host; the Home
  # Manager profile applies on every host, and per-host extras are
  # delivered by feature aspects through provides.to-users.
  den.aspects.codyt = {
    # primary-user: isNormalUser plus the wheel and networkmanager groups.
    # user-shell: zsh as the login shell, with programs.zsh enabled on the host and in Home
    # Manager (the shell aspect in modules/shell/ configures zsh itself).
    includes = [
      den.batteries.primary-user
      (den.batteries.user-shell "zsh")
    ];

    user = {
      description = "Cody Tucker";
      extraGroups = [
        "media"
        "scanner"
        "lp"
        "input"
        "documents"
      ];
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
    # den.default (shell, git, nixvim, harness, ...); host-specific extras come from
    # the feature aspects' provides.to-users.
    homeManager.imports = [
      inputs.nixos-secrets.homeModules.default
    ];
  };
}
