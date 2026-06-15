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
    rev = "v1.3.0";
    hash = "sha256-nqdVWDzBD8zv/OsvAVrxA71ox8l0uacQqt4pf1PSJ1U=";
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
          | .presets.openai.fast.model = "openai/gpt-5.4-mini-fast"
          | .presets.openai.fast.description = "GPT-5.4 Mini Fast for fast exploration and simple tasks"
          | .presets.openai.medium.model = "openai/gpt-5.5-fast"
          | .presets.openai.medium.variant = "high"
          | .presets.openai.medium.description = "GPT-5.5 Fast high for implementation and standard coding"
          | .presets.openai.heavy.model = "openai/gpt-5.4"
          | .presets.openai.heavy.variant = null
          | .presets.openai.heavy.description = "GPT-5.4 for architecture and complex tasks"
        ' "$out/tiers.json" > "$tmp_json"
        mv "$tmp_json" "$out/tiers.json"
      '';

  pluginPath = "${config.xdg.configHome}/opencode/plugins/model-router.ts";
in
{
  home.activation.opencodeModelRouter = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    plugin_dir="${config.xdg.configHome}/opencode/plugins"
    router_dir="$plugin_dir/model-router"
    loader_file="$plugin_dir/model-router.ts"

    mkdir -p "$plugin_dir"
    rm -rf "$router_dir"
    cp -r ${modelRouterSrc} "$router_dir"
    chmod -R u+w "$router_dir"

    cat > "$loader_file" <<'EOF'
    export { default } from "./model-router/src/index.ts"
    EOF
  '';

  programs.opencode.settings.plugin = [ pluginPath ];
}
