{ lib, pkgs, ... }:
let
  delegationPlugins = pkgs.fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-official-plugins";
    rev = "bedc9e74ef792864cd7198a8e43cedd5b585ace7";
    hash = "sha256-Dp9707nwpbsOe0N1hDuzvl7oHyP97G8puiNRQZz3bWs=";
  };
  advancedDelegationPlugin = pkgs.runCommand "advanced-delegation" { } ''
    cp -R ${delegationPlugins}/advanced-delegation "$out"
    # The pinned Hermes has the delegation-provider API but reports 0.0.0.
    substituteInPlace "$out/plugin.yaml" \
      --replace-fail 'requires_hermes: ">=0.22.5"' 'requires_hermes: ">=0.0.0"'
  '';
in
{
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 1100 [ advancedDelegationPlugin ];
    settings = {
      delegation = {
        backend = "model_map";
        backends.model_map.options = [
          {
            name = "fast";
            description = "Narrow lookups, simple summaries, and straightforward edits.";
            provider = "opencode-go";
            model = "deepseek-v4.1-flash";
          }
          {
            name = "medium";
            description = "Multi-step research, ordinary implementation, and analysis.";
            provider = "opencode-go";
            model = "hy4";
          }
          {
            name = "heavy";
            description = "Difficult debugging, architecture, and consequential reviews.";
            provider = "openai-codex";
            model = "gpt-6.1-sol";
            reasoning_effort = "high";
          }
        ];
      };
    };
  };
}
