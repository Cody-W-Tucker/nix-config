{
  xdg.mime.enable = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Set feh as the default for all image types
      "image/bmp" = "feh.desktop";
      "image/g3fax" = "feh.desktop";
      "image/gif" = "feh.desktop";
      "image/x-fits" = "feh.desktop";
      "image/x-pcx" = "feh.desktop";
      "image/x-portable-anymap" = "feh.desktop";
      "image/x-portable-bitmap" = "feh.desktop";
      "image/x-portable-graymap" = "feh.desktop";
      "image/x-portable-pixmap" = "feh.desktop";
      "image/x-psd" = "feh.desktop";
      "image/x-sgi" = "feh.desktop";
      "image/x-tga" = "feh.desktop";
      "image/x-xbitmap" = "feh.desktop";
      "image/x-xwindowdump" = "feh.desktop";
      "image/x-xcf" = "feh.desktop";
      "image/x-compressed-xcf" = "feh.desktop";
      "image/tiff" = "feh.desktop";
      "image/jpeg" = "feh.desktop";
      "image/x-psp" = "feh.desktop";
      "application/postscript" = "feh.desktop";
      "image/png" = "feh.desktop";
      "image/x-icon" = "feh.desktop";
      "image/x-xpixmap" = "feh.desktop";
      "image/x-exr" = "feh.desktop";
      "image/x-webp" = "feh.desktop";
      "image/heif" = "feh.desktop";
      "image/heic" = "feh.desktop";
      "image/svg+xml" = "feh.desktop";
      "image/x-wmf" = "feh.desktop";
      "image/jp2" = "feh.desktop";
      "image/x-xcursor" = "feh.desktop";

      # Set Zathura for PDFs
      "application/epub+zip" = "org.pwmt.zathura.desktop";
      "application/pdf" = "org.pwmt.zathura.desktop";

      # Set nvim as the default for all text types
      "application/rtf" = "nvim.desktop";
      "application/vnd.mozilla.xul+xml" = "nvim.desktop";
      "application/xhtml+xml" = "nvim.desktop";
      "application/xml" = "nvim.desktop";
      "application/x-shellscript" = "nvim.desktop";
      "application/x-wine-extension-ini" = "nvim.desktop";
      "application/zip" = "nvim.desktop";
      "text/english" = "nvim.desktop";
      "text/html" = "nvim.desktop";
      "text/markdown" = "nvim.desktop";
      "text/plain" = "nvim.desktop";
      "text/x-log" = "nvim.desktop";
      "text/x-makefile" = "nvim.desktop";
      "text/x-c++hdr" = "nvim.desktop";
      "text/x-c++src" = "nvim.desktop";
      "text/x-chdr" = "nvim.desktop";
      "text/x-csrc" = "nvim.desktop";
      "text/x-java" = "nvim.desktop";
      "text/x-moc" = "nvim.desktop";
      "text/x-pascal" = "nvim.desktop";
      "text/x-tcl" = "nvim.desktop";
      "text/x-tex" = "nvim.desktop";
      "text/xml" = "nvim.desktop";
      "text/x-c" = "nvim.desktop";
      "text/x-c++" = "nvim.desktop";

      # Use zen for http/s
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
    };
  };
}
