{ pkgs, ... }:

{
  imports = [
    ./keymaps.nix
    ./plugins/lsp.nix
    ./plugins/none-ls.nix
    ./plugins/conform.nix
    ./plugins/cmp.nix
    ./plugins/lualine.nix
    ./plugins/telescope.nix
    ./plugins/treesitter.nix
    ./plugins/startup.nix
    ./plugins/ts-autotag.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        transparent_background = true;
      };
    };
    clipboard = {
      # Use system clipboard
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
    };
    autoCmd = [
      {
        event = [
          "BufReadPost"
          "BufWritePost"
          "FileType"
        ];
        pattern = [ "*.md" ];
        # Uncomment to use with only markdown
        command = "setlocal spell spelllang=en_us";
      }
      # Enable inline completion for copilot
      {
        event = "LspAttach";
        callback = {
          __raw = ''
            function(args)
              local bufnr = args.buf
              local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
              if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr) then
                vim.lsp.inline_completion.enable(true, { bufnr = bufnr })
                vim.keymap.set(
                  "i",
                  "<C-F>",
                  vim.lsp.inline_completion.get,
                  { desc = "LSP: accept inline completion", buffer = bufnr }
                )
                vim.keymap.set(
                  "i",
                  "<C-G>",
                  vim.lsp.inline_completion.select,
                  { desc = "LSP: switch inline completion", buffer = bufnr }
                )
              end
            end
          '';
        };
      }
    ];
    plugins = {
      csvview.enable = true;
      nix.enable = true;
      lazygit.enable = true;
      git-conflict.enable = true;
      gitsigns.enable = true;
      markdown-preview.enable = true;
      commentary.enable = true;
      which-key.enable = true;
      rainbow-delimiters.enable = true;
      snacks.enable = true;
      yazi.enable = true;
      web-devicons.enable = true;
      direnv.enable = true;
      zig.enable = true;
    };
    # Set the leader key to <Space>
    globals.mapleader = " ";
    extraPlugins = with pkgs.vimPlugins; [ vim-pencil ];
    extraPackages = with pkgs; [ zig ];
  };
}
