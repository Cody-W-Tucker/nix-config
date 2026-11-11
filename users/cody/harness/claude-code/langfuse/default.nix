# Langfuse observability plugin for Claude Code.
#
# Credentials come from the same SOPS `opencode-langfuse-env` template that
# ../../opencode/default.nix sources into interactive zsh (LANGFUSE_PUBLIC_KEY,
# LANGFUSE_SECRET_KEY, LANGFUSE_BASE_URL). The hook reads those plain env vars,
# so no keys pass through the plugin's keychain-backed userConfig.
{ options, pkgs, ... }:
let
  # langfuse 4.15.2 needs uv_build>=0.11.2; release-26.05 (nas) ships 0.10.0.
  # Build from unstable on every host so all share one tested Python closure.
  plugin = pkgs.callPackage ./package.nix { inherit (pkgs.unstable) python3; };
in
{
  # home-manager release-26.05 only accepts a list; unstable prefers named
  # plugins and warns on the list form.
  programs.claude-code.plugins =
    if builtins.isList options.programs.claude-code.plugins.default then
      [ plugin ]
    else
      { langfuse-observability = plugin; };
}
