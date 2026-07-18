{ config, pkgs, ... }:

let
  plugin99 = pkgs.callPackage ../../../packages/99 { };
in
{
  programs.nixvim = {
    extraPlugins = [ plugin99 ];

    extraConfigLua = ''
      local _99 = require("99")

      _99.setup({
        provider = _99.Providers.OpenCodeProvider,
        model = "opencode-go/kimi-k2.7-code",
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
}
