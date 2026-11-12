{
  # Keep the OpenRazer daemon, but don't launch Polychromatic's tray applet.
  xdg.configFile."autostart/polychromatic-autostart.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
}
