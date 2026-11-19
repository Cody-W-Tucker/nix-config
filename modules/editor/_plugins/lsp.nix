_:

let
  # getSubOptions alone includes shared modules, but not the user's imports.
  # Extend the existing submodule type so its specialArgs are preserved too.
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
              # One option set per host (they run different nixpkgs releases
              # and profiles), plus Home Manager for everything under users/.
              # Each set includes the codyos.* options declared in modules/.
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
        dockerls.enable = true; # Docker
        bashls.enable = true; # Bash
        marksman.enable = true; # Markdown
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
