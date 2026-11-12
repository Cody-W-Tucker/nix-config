{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  officialPlugins = pkgs.fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-official-plugins";
    rev = "a4e311e433f1470b1fec15434deea6a05e8644eb";
    hash = "sha256-q9gpwik7FUp2z6H69z5eoq7qNZYvdi6KvU7fOG796C4=";
  };
  plugin = pkgs.runCommand "claude-subscription-directsdk" { } ''
    cp -R ${officialPlugins}/claude-subscription-directsdk "$out"
    # The Nix-packaged Hermes reports 0.0.0 despite having the provider API.
    substituteInPlace "$out/plugin.yaml" \
      --replace-fail 'requires_hermes: ">=0.21.4"' 'requires_hermes: ">=0.0.0"'
  '';
  claude = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
in
{
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 900 [ plugin ];
    environment.CLAUDE_SUBSCRIPTION_DIRECTSDK_COMMAND = "${claude}/bin/claude";
  };
}
