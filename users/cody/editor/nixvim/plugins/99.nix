{
  config,
  lib,
  pkgs,
  ...
}:

let
  plugin99 = pkgs.callPackage ../../../desktop/packages/99 { };
in
{
  options.cody.editor."99".enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether the 99 nixvim integration is enabled. When enabled, the 99
      plugin provides its own OpenCode-backed model routing, so the
      OpenCode model-router plugin is disabled.
    '';
  };

  config = lib.mkIf config.cody.editor."99".enable {
    programs.nixvim = {
      extraPlugins = [ plugin99 ];

      extraConfigLua = ''
        local _99 = require("99")

        _99.setup({
          provider = _99.Providers.OpenCodeProvider,
          model = "litellm/hy3",
          completion = {
            source = "cmp",
            custom_rules = {
              "${config.home.homeDirectory}/.config/opencode/skills",
              "/etc/nixos/.agents/skills",
            },
          },
          md_files = { "AGENTS.md" },
          tmp_dir = "./tmp",
        })

        local ok, wk = pcall(require, "which-key")
        if ok then
          wk.add({
            { "<leader>9", group = "99" },
          })
        end
      '';
    };
  };
}
