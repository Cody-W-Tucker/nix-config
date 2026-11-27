{ den, inputs, ... }:
{
  den.aspects.codyt = {
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

    homeManager.imports = [
      inputs.nixos-secrets.homeModules.default
    ];
  };
}
