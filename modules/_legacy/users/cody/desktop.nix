# Beast's Home Manager role entry, slimmed by the desktop slice: everything desktop moved to
# modules/desktop/* (delivered by den.aspects.desktop). What remains is the shared user
# environment and editor pieces that the user/editor slice will take over.
{
  osConfig,
  config,
  ...
}:

let
  inherit (osConfig.codyos.site) domain;
in
{
  sops.secrets."opencode-password" = { };

  imports = [
    ./core.nix
    ./editor/nixvim/plugins/desktop.nix
  ];

  # The NAS OpenCode server uses HTTP Basic auth. Scope its secret to the
  # explicit remote alias so regular `op` sessions remain local.
  programs.zsh.shellAliases.op- = ''
    OPENCODE_SERVER_PASSWORD="$(<${config.sops.secrets."opencode-password".path})" \
    opencode --server https://opencode.${domain}
  '';
}
