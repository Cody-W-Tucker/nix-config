{
  # Beast's client for the NAS OpenCode server (den.aspects.opencode, modules/services/
  # opencode.nix). The server uses HTTP Basic auth; scope its secret to the explicit remote
  # alias so regular `op` sessions remain local. Included by beast only.
  den.aspects.opencode-remote.provides.to-users.homeManager =
    { osConfig, config, ... }:
    let
      inherit (osConfig.codyos.site) domain;
    in
    {
      sops.secrets."opencode-password" = { };

      programs.zsh.shellAliases.op- = ''
        OPENCODE_SERVER_PASSWORD="$(<${config.sops.secrets."opencode-password".path})" \
        opencode --server https://opencode.${domain}
      '';
    };
}
