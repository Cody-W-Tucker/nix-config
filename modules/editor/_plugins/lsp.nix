_:

let
  homeOptions = host: ''
    let
      host = (builtins.getFlake (toString ./.)).nixosConfigurations.${host};
      user = host.config.codyos.site.user.name;
      option = host.options.home-manager.users;
      modules = option.type.getSubModules ++ map (d: d.''${user} or {}) option.definitions;
    in (option.type.substSubModules modules).getSubOptions []
  '';
in
{
  programs.nixvim.plugins = {
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        nixd = {
          enable = true;
          settings = {
            nixd = {
              nixpkgs = {
                expr = "import (builtins.getFlake (toString ./.)).inputs.nixpkgs-unstable { }";
              };
              formatting = {
                command = [ "nixfmt" ];
              };
              options = {
                beast = {
                  expr = "(builtins.getFlake (toString ./.)).nixosConfigurations.beast.options";
                };
                nas = {
                  expr = "(builtins.getFlake (toString ./.)).nixosConfigurations.nas.options";
                };
                home-manager-beast = {
                  expr = homeOptions "beast";
                };
                home-manager-nas = {
                  expr = homeOptions "nas";
                };
              };
            };
          };
        };
        ast_grep = {
          enable = true;
          filetypes = [ "nix" ];
        };
        dockerls.enable = true;
        bashls.enable = true;
        marksman.enable = true;
      };
      keymaps = {
        silent = true;
        lspBuf = {
          gd = "definition";
          gD = "references";
          gt = "type_definition";
          gi = "implementation";
          K = "hover";
          re = "rename";
          ca = "code_action";
        };
        diagnostic = {
          "<leader>k" = "goto_prev";
          "<leader>j" = "goto_next";
        };
      };
    };
  };
}
