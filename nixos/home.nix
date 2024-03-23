{ pkgs, config, inputs, lib, gtkThemeFromScheme, ... }:

let
  scriptNames = [
    "rofi-launcher"
    "bluetoothSwitch"
    "wallpaper"
  ];

  scriptPackages = map (script: import ./config/scripts/${script}.nix { inherit pkgs; }) scriptNames;

  apply-hm-env = pkgs.writeShellScript "apply-hm-env" ''
    ${lib.optionalString (config.home.sessionPath != []) ''
      export PATH=${builtins.concatStringsSep ":" config.home.sessionPath}:$PATH
    ''}
    ${builtins.concatStringsSep "\n" (
      lib.mapAttrsToList (k: v: ''
        export ${k}=${toString v}
      '')
      config.home.sessionVariables
    )}
    ${config.home.sessionVariablesExtra}
    exec "$@"
  '';

  # runs processes as systemd transient services
  run-as-service = pkgs.writeShellScriptBin "run-as-service" ''
    exec ${pkgs.systemd}/bin/systemd-run \
      --slice=app-manual.slice \
      --property=ExitType=cgroup \
      --user \
      --wait \
      bash -lc "exec ${apply-hm-env} $@"
  '';
in
{
  home.packages = with pkgs; [
    # Add some packages to the user environment.
    dconf
    grim
    slurp
    wl-clipboard
    hyprpicker
    hyprlock
    hypridle
    starship
    google-chrome
    zoom-us
    xwaylandvideobridge
    waybar
    mako
    swww
    kitty
    rofi-wayland
    vscode
    gcalcli
    spotify
    openrazer-daemon
    todoist-electron
    obsidian
    brightnessctl
    gh
    run-as-service
  ] ++ scriptPackages;

  colorScheme = inputs.nix-colors.colorSchemes."google-dark";

  imports = [
    ./config/home
    inputs.nix-colors.homeManagerModules.default
    inputs.hyprland.homeManagerModules.default
  ];
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };
  # X keyboard
  home.keyboard = {
    layout = "us";
    model = "pc104";
  };
  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.gnome.adwaita-icon-theme;
      name = "Adwaita";
    };
    theme = {
      name = "${config.colorScheme.slug}";
      package = gtkThemeFromScheme { scheme = config.colorScheme; };
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # Theme QT -> GTK
  qt = {
    enable = true;
    platformTheme = "gtk";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };
  home.sessionVariables = {
    BROWSER = "google-chrome";
    EDITOR = "code --wait";
    VISUAL = "code";
    TERMINAL = "kitty";
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER = "va_gl";
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    GDK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "23.11";
}
