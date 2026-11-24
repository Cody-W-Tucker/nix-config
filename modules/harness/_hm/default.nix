# Harness root module. `localAi` (host attribute, passed by den.aspects.harness) selects
# whether the NAS-backed services are local; it is also used while resolving `imports`.
{ localAi }:
{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  piLangfuseDir = "${config.home.homeDirectory}/.pi/agent/langfuse-plugin";
in

{
  imports = [
    ./claude-code
    ./codex
    ./opencode
    ./context.nix
    ./inbox
    (import ./mcp.nix { inherit localAi; })
    (import ./plugins { inherit localAi; })
    ./skills
    ./coding-tools.nix
  ]
  ++
    lib.optionals
      (
        localAi
        && !(builtins.pathExists "${inputs.home-manager-stable}/modules/programs/pi-coding-agent.nix")
      )
      [
        "${inputs.home-manager}/modules/programs/pi-coding-agent.nix"
      ];

  home.packages = [
    llmPkgs.cursor-agent
    llmPkgs.muse-code
    llmPkgs.grok

    # Agent workspace: persistent agent terminals. The NAS core is the shared
    # remote that Beast's herdr-app reaches over SSH; both use this pinned hc.
    llmPkgs.herdr-core

    llmPkgs.tuicr

    llmPkgs.spec-kit
    llmPkgs.backlog-md
  ];

  programs.pi-coding-agent = {
    enable = true;
    package = llmPkgs.pi;
  };

  # Pi discovers this entrypoint globally; dependencies live outside the
  # extension directory so their own files are not discovered as extensions.
  home.file.".pi/agent/extensions/langfuse.ts".text = ''
    export { default } from "${piLangfuseDir}/node_modules/@langfuse/pi-observability-plugin/src/index.ts";
  '';
  home.activation.piLangfusePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${lib.getBin pkgs.nodejs}/bin:$PATH"
    plugin_dir="${piLangfuseDir}"
    manifest="$plugin_dir/node_modules/@langfuse/pi-observability-plugin/package.json"
    version="$(node -p "require('$manifest').version" 2>/dev/null || true)"
    if [ "$version" != "0.1.2" ]; then
      mkdir -p "$plugin_dir"
      npm install --prefix "$plugin_dir" --no-save --no-package-lock --ignore-scripts --no-audit --no-fund '@langfuse/pi-observability-plugin@0.1.2'
    fi
  '';

  xdg.configFile."deja/exclude".text = ''
    harness:pi
  '';

  # tuicr: match stylix catppuccin-mocha palette
  xdg.configFile."tuicr/config.toml".source = ./tuicr.toml;
}
