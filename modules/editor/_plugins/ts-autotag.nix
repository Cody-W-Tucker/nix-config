{
  programs.nixvim.plugins.ts-autotag = {
    enable = true;
    settings = {
      opts = {
        enable_close = true;
        enable_rename = true;
        enable_close_on_slash = false;
      };
      per_filetype = {
        astro = {
          enable_close = true;
          enable_rename = true;
        };
        javascriptreact = {
          enable_close = true;
          enable_rename = true;
        };
        typescriptreact = {
          enable_close = true;
          enable_rename = true;
        };
        html = {
          enable_close = false;
        };
      };
    };
  };
}
