{
  inputs,
  pkgs,
  config,
  lib,
  osConfig,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  piLangfuseDir = "${config.home.homeDirectory}/.pi/agent/langfuse-plugin";
in

{
  imports = [
    ./claude-code
    ./opencode
    ./context.nix
    ./mcp.nix
    ./plugins
    ./skills
  ]
  ++
    lib.optionals
      (
        osConfig.networking.hostName == "nas"
        && !(builtins.pathExists "${inputs.home-manager-stable}/modules/programs/pi-coding-agent.nix")
      )
      [
        "${inputs.home-manager}/modules/programs/pi-coding-agent.nix"
      ];

  home.packages = [
    # Harness Packages
    pkgs.codex
    llmPkgs.cursor-agent
    llmPkgs.muse-code
    llmPkgs.grok

    # Agent workspace: persistent agent terminals. The NAS core is the shared
    # remote that Beast's herdr-app reaches over SSH; both use this pinned hc.
    llmPkgs.herdr-core

    # Memory and Session Management
    llmPkgs.deja-vu # session search across all agents
    pkgs.sqlite # Deja Vu reads OpenCode and Hermes session databases with sqlite3.

    # Git and Code Review
    llmPkgs.tuicr
    llmPkgs.gnhf
    llmPkgs.no-mistakes # Git push gate: runs an AI-driven validation pipeline, then opens a clean PR.

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
