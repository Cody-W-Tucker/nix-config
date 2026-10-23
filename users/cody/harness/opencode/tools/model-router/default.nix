{
  config,
  lib,
  pkgs,
  ...
}:

let
  upstreamSrc = pkgs.fetchFromGitHub {
    owner = "marco-jardim";
    repo = "opencode-model-router";
    # Includes the OpenCode V2 adapter (server.ts), supported by OpenCode 2.0.20+.
    rev = "841fa6ed977fc45a115ce32525fb57f84ea5a6aa";
    hash = "sha256-n4jIqAj7ulQ1ttbOL4EP8qfwNBCpUV1N20ZG39eWagc=";
  };

  modelRouterSrc =
    pkgs.runCommandLocal "opencode-model-router-src"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        cp -r ${upstreamSrc} "$out"
        chmod -R u+w "$out"

        tmp_json="$TMPDIR/tiers.json"
        jq '
          .activePreset = "openai"
          | .presets.openai.fast.model = "openai/gpt-6-luna"
          | .presets.openai.fast.description = "fast exploration and simple tasks"
          | .presets.openai.medium.model = "opencode-go/muse-spark-1.3-contributor"
          | .presets.openai.medium.variant = "high"
          | .presets.openai.medium.description = "implementation, refactors, and standard coding work"
          | .presets.openai.heavy.model = "openai/gpt-6-sol"
          | .presets.openai.heavy.variant = "high"
          | .presets.openai.heavy.description = "architecture and complex tasks"
        ' "$out/tiers.json" > "$tmp_json"
        mv "$tmp_json" "$out/tiers.json"
      '';

  pluginPath = "${config.xdg.configHome}/opencode/plugins/model-router";
in
{
  home.activation.opencodeModelRouter = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    plugin_dir="${config.xdg.configHome}/opencode/plugins"
    router_dir="$plugin_dir/model-router"

    mkdir -p "$plugin_dir"
    rm -rf "$router_dir"
    cp -r ${modelRouterSrc} "$router_dir"
    chmod -R u+w "$router_dir"
    rm -f "$plugin_dir/model-router.ts"
  '';

  programs.opencode.settings.plugins = [ pluginPath ];
}
