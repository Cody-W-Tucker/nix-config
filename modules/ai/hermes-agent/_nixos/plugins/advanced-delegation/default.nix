{ lib, pkgs, ... }:
let
  advancedDelegationPlugin = import ../lib/build-plugin.nix pkgs {
    name = "advanced-delegation";
    rev = "bedc9e74ef792864cd7198a8e43cedd5b585ace7";
    hash = "sha256-Dp9707nwpbsOe0N1hDuzvl7oHyP97G8puiNRQZz3bWs=";
    requiresHermes = "0.22.5";
  };
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
            description = "Preferred for initial context gathering, focused read-only exploration, and lookups.";
            provider = "opencode-go";
            model = "deepseek-v4.1-flash";
          }
          {
            name = "medium";
            description = "Routine implementation, refactoring, and targeted verification.";
            provider = "opencode-go";
            model = "hy4";
          }
          {
            name = "heavy";
            description = "Complex debugging, architecture, security review, and consequential tradeoffs.";
            provider = "openai-codex";
            model = "gpt-6.1-sol";
            reasoning_effort = "high";
          }
        ];
      };
    };
  };
}
