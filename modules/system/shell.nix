# Shell configuration (zsh, starship)

{ ... }:

{
  programs = {
    starship = {
      enable = true;
    };
    zsh = {
      enable = true;
      # Disable the completion in the global module because it would call compinit
      # but the home manager config also calls compinit. This causes the cache to be invalidated
      # because the fpath changes in-between, causing constant re-evaluation and thus startup
      # times of 1-2 seconds. Disable the completion here and only keep the home-manager one to fix it.
      enableCompletion = false;
    };
  };
}
