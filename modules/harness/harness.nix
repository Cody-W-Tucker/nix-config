{
  # AI/operator harness for the user: Claude Code, OpenCode client, shared MCP servers,
  # plugins and skills (the module tree is _hm). `localAi` (host attribute: true where
  # llama-swap, Hindsight and QMD run on the host itself) is read from `host` here and
  # handed down; modules use it to choose local vs NAS endpoints.
  #
  # The OpenCode client config pairs with modules/services/opencode.nix: both contribute
  # to systemd.user.services.opencode-web.Service.EnvironmentFile (listOf, concatenated).
  den.aspects.harness.homeManager =
    { host, ... }:
    {
      imports = [ (import ./_hm { inherit (host) localAi; }) ];
    };
}
