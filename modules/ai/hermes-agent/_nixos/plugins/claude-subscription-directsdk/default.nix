{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  plugin = import ../lib/build-plugin.nix pkgs {
    name = "claude-subscription-directsdk";
    rev = "a4e311e433f1470b1fec15434deea6a05e8644eb";
    hash = "sha256-q9gpwik7FUp2z6H69z5eoq7qNZYvdi6KvU7fOG796C4=";
    requiresHermes = "0.21.4";
  };
  claude = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
in
{
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 900 [ plugin ];
    environment.CLAUDE_SUBSCRIPTION_DIRECTSDK_COMMAND = "${claude}/bin/claude";
  };
}
