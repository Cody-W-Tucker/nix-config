{
  config,
  inputs,
  pkgs,
  self,
  lib,
  ...
}:

{
  programs = {
    yazi = {
      # Yazi file viewer
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "y";
      plugins.git = pkgs.yaziPlugins.git;
      settings.plugin.prepend_fetchers = [
        {
          id = "git";
          url = "*";
          run = "git";
        }
        {
          id = "git";
          url = "*/";
          run = "git";
        }
      ];
      initLua = ''
        th.git = th.git or {}
        th.git.modified = ui.Style():fg("#${config.lib.stylix.colors.base0A}")
        th.git.added = ui.Style():fg("#${config.lib.stylix.colors.base0B}")
        th.git.deleted = ui.Style():fg("#${config.lib.stylix.colors.base08}")
        th.git.updated = ui.Style():fg("#${config.lib.stylix.colors.base0D}")
        th.git.untracked = ui.Style():fg("#${config.lib.stylix.colors.base0C}")

        require("git"):setup()
      '';
    };
    "crm-cli" = {
      enable = true;
      autoMount = true; # Mount the crm to a virtual filesystem to view leads, contacts, etc. on "disk."
      settings.mount.default_path = "${config.home.homeDirectory}/Knowledge/CRM";
    };
    gh = {
      # Enable GitHub CLI
      enable = true;
      extensions = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.gh-star-search
      ];
    };
    zsh = {
      shellAliases = {
        ssh- = "kitty +kitten ssh";
        rr = "yazi";
        copy = "kitten clipboard";
      };
      plugins = [
        {
          name = "vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
      ];
      initContent = ''
        # Fix fzf key bindings compatibility with zsh-vi-mode
        function zvm_after_init() {
          # Re-initialize fzf key bindings after zsh-vi-mode loads
          if command -v fzf-share >/dev/null; then
            source "$(fzf-share)/key-bindings.zsh"
            source "$(fzf-share)/completion.zsh"
          fi
        }
      '';
    };
    fzf = {
      colors = lib.mkForce {
        "fg+" = "#" + config.lib.stylix.colors.base0D;
        "bg+" = "-1";
        "fg" = "#" + config.lib.stylix.colors.base05;
        "bg" = "-1";
        "prompt" = "#" + config.lib.stylix.colors.base03;
        "pointer" = "#" + config.lib.stylix.colors.base0D;
      };
      defaultOptions = [
        "--margin=1"
        "--layout=reverse"
        "--border=none"
        "--info='hidden'"
        "--header=''"
        "--prompt='/ '"
        "-i"
        "--no-bold"
        "--preview='bat --style=numbers --color=always --line-range :500 {}'"
        "--preview-window=right:60%:wrap"
      ];
    };
    kitty = {
      enable = true;
      settings = {
        shell_integration = "no-cursor";
        window_padding_width = "0 8";
        confirm_os_window_close = "0";
        wayland_titlebar_color = "system";
        cursor_shape = "block";
        enable_audio_bell = "no";
        cursor_trail = 1;
        cursor_trail_start_threshold = 3;
        cursor_trail_decay = "0.1 0.4";
        tab_bar_style = "powerline";
      };
      extraConfig = ''
        foreground #${config.lib.stylix.colors.base05}
        background #${config.lib.stylix.colors.base00}
        color0  #${config.lib.stylix.colors.base03}
        color1  #${config.lib.stylix.colors.base08}
        color2  #${config.lib.stylix.colors.base0B}
        color3  #${config.lib.stylix.colors.base09}
        color4  #${config.lib.stylix.colors.base0D}
        color5  #${config.lib.stylix.colors.base0E}
        color6  #${config.lib.stylix.colors.base0C}
        color7  #${config.lib.stylix.colors.base06}
        color8  #${config.lib.stylix.colors.base04}
        color9  #${config.lib.stylix.colors.base08}
        color10 #${config.lib.stylix.colors.base0B}
        color11 #${config.lib.stylix.colors.base0A}
        color12 #${config.lib.stylix.colors.base0C}
        color13 #${config.lib.stylix.colors.base0E}
        color14 #${config.lib.stylix.colors.base0C}
        color15 #${config.lib.stylix.colors.base07}
        color16 #${config.lib.stylix.colors.base00}
        color17 #${config.lib.stylix.colors.base0F}
        color18 #${config.lib.stylix.colors.base0B}
        color19 #${config.lib.stylix.colors.base09}
        color20 #${config.lib.stylix.colors.base0D}
        color21 #${config.lib.stylix.colors.base0E}
        color22 #${config.lib.stylix.colors.base0C}
        color23 #${config.lib.stylix.colors.base06}
        cursor  #${config.lib.stylix.colors.base07}
        cursor_text_color #${config.lib.stylix.colors.base00}
        selection_foreground #${config.lib.stylix.colors.base01}
        selection_background #${config.lib.stylix.colors.base0D}
        url_color #${config.lib.stylix.colors.base0C}
        active_border_color #${config.lib.stylix.colors.base04}
        inactive_border_color #${config.lib.stylix.colors.base00}
        bell_border_color #${config.lib.stylix.colors.base03}
        tab_bar_style fade
        tab_fade 1
        active_tab_foreground   #${config.lib.stylix.colors.base05}
        active_tab_background   #${config.lib.stylix.colors.base01}
        active_tab_font_style   bold
        inactive_tab_foreground #${config.lib.stylix.colors.base07}
        inactive_tab_background #${config.lib.stylix.colors.base00}
        inactive_tab_font_style normal
        tab_bar_background #${config.lib.stylix.colors.base00}
      '';
    };
    bat = {
      themes =
        let
          src = pkgs.fetchFromGitHub {
            owner = "catppuccin";
            repo = "bat";
            rev = "ba4d16880d63e656acced2b7d4e034e4a93f74b1";
            hash = "sha256-6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
          };
        in
        {
          Catppuccin-mocha = {
            inherit src;
            file = "Catppuccin-mocha.tmTheme";
          };
        };
    };
    chromium = {
      enable = true;
      # Chromecast improvement
      commandLineArgs = [ "--load-media-router-component-extension=1" ];
    };
    obs-studio = {
      # Obs for screenrecording
      enable = true;
    };
    firefox = {
      # Zen browser via Firefox module
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
      # Replace firefox with zen browser to use home manager module
      package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
      profiles.default = {
        # hardware acceleration settings
        settings = {
          # Enable VA-API video decoding
          "media.ffmpeg.vaapi.enabled" = true;
          # Enable hardware decoding
          "media.hardware-video-decoding.enabled" = true;
          # Enable WebRender for better GPU acceleration
          "gfx.webrender.all" = true;
          "gfx.webrender.enabled" = true;
          # Additional video-path settings
          "media.ffmpeg.dmabuf-textures.enabled" = true;
          "media.rdd-ffmpeg.enabled" = true;
          # Disable software fallback for video decoding
          "media.decoder-doctor.notifications-allowed" = false;
        };
      };
    };
  };
}
