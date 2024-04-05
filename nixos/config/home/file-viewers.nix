{ config, pkgs, lib, ... }: {

  # Also Using feh image viewer

  # Ranger Configuration
  programs.ranger = {
    enable = true;
    settings = {
      preview_images = true;
      preview_images_method = "kitty";
    };
    mappings = {
      C-d = "shell ripdrag %p -x 2>/dev/null &";
    };
  };

  # Enable the Zathura PDF viewer
  programs.zathura = {
    enable = true;
    package = pkgs.zathura;
    options = {
      adjust-open = "best-fit";
      pages-per-row = 1;
      scroll-page-aware = true;
      smooth-scroll = true;
      scroll-full-overlap = 0.01;
      scroll-step = 100;
      zoom-min = 10;
      guioptions = "";
      font = "inconsolata 15";
      default-bg = "#000000";
      default-fg = "#F7F7F6";
      statusbar-fg = "#B0B0B0";
      statusbar-bg = "#202020";
      inputbar-bg = "#151515";
      inputbar-fg = "#FFFFFF";
      notification-error-bg = "#AC4142";
      notification-error-fg = "#151515";
      notification-warning-bg = "#AC4142";
      notification-warning-fg = "#151515";
      highlight-color = "#F4BF75";
      highlight-active-color = "#6A9FB5";
      completion-highlight-fg = "#151515";
      completion-highlight-bg = "#90A959";
      completion-bg = "#303030";
      completion-fg = "#E0E0E0";
      notification-bg = "#90A959";
      notification-fg = "#151515";
      recolor = true;
      recolor-lightcolor = "#000000";
      recolor-darkcolor = "#E0E0E0";
      recolor-reverse-video = true;
      recolor-keephue = true;
      render-loading = false;
    };
    mappings = {
      f = "toggle_fullscreen";
      "[fullscreen] f" = "toggle_fullscreen";
    };
  };
}
