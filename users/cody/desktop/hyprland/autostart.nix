{
  wayland.windowManager.hyprland.extraConfig = ''
    -- MUST BE FIRST - Environment setup
    hl.on("hyprland.start", function()
      hl.exec_cmd("uwsm finalize")

      -- hl.exec_cmd("uwsm app -- feishin") -- Music player
    end)
  '';
}
