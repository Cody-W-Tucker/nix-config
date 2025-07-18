{
  imports = [
    ./cli
  ];

  config = {

    # Keyboard
    home.keyboard = {
      layout = "us";
      model = "pc105";
    };

    # Git configuration
    programs.git = {
      enable = true;

      # Basic user configuration
      userName = "Cody Tucker";
      userEmail = "cody@tmvsocial.com";

      # Useful aliases
      aliases = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        ca = "commit -a";
        cm = "commit -m";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "!gitk";
        lg = "log --oneline --graph --decorate";
        lga = "log --oneline --graph --decorate --all";
      };

      # Global gitignore
      ignores = [
        ".DS_Store"
        "*.swp"
        "*.swo"
        "*~"
        ".nix-shell"
      ];

      # Additional configuration
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core.editor = "nvim";
        color.ui = "auto";
        color.branch = "auto";
        color.diff = "auto";
        color.status = "auto";
      };
    };

    # The state version is required and should stay at the version you originally installed.
    home.stateVersion = "24.05";
  };
}
