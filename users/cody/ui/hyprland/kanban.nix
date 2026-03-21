{
  wayland.windowManager.hyprland.settings = {
    # Kanban special workspaces - windows flow through these automatically
    workspace = [
      "special:kanban-init, persistent:false, on-created-empty:exec kitty --class kanban-init -T 'Kanban: Init'"
      "special:kanban-progress, persistent:false, on-created-empty:exec kitty --class kanban-progress -T 'Kanban: In Progress'"
      "special:kanban-review, persistent:false, on-created-empty:exec kitty --class kanban-review -T 'Kanban: Review'"
      "special:kanban-done, persistent:false"
    ];

    # Window rules for kanban lanes
    windowrule = [
      # Move kanban windows to their respective special workspaces
      "match:class ^kanban-init$, workspace special:kanban-init silent"
      "match:class ^kanban-progress$, workspace special:kanban-progress silent"
      "match:class ^kanban-review$, workspace special:kanban-review silent"
      "match:class ^kanban-done$, workspace special:kanban-done silent"

      # Init lane - ready to start
      "match:workspace ^(special:kanban-init)$"

      # Progress lane - actively working
      "match:workspace ^(special:kanban-progress)$"

      # Review lane - needs attention
      "match:workspace ^(special:kanban-review)$"
      "match:workspace ^(special:kanban-review)$"

      # Done lane - dimmed, gray border
      "match:workspace ^(special:kanban-done)$"

      # Auto-tile kanban windows
      "match:class ^(kanban-init|kanban-progress|kanban-review|kanban-done)$, tile on"
    ];

    bind = [
      # Launch kanban task picker
      "SUPER, K, exec, kanban-launcher"

      # Toggle kanban workspaces
      "SUPER SHIFT, K, togglespecialworkspace, kanban-progress"
      "SUPER CTRL, K, togglespecialworkspace, kanban-review"
      "SUPER ALT, K, togglespecialworkspace, kanban-done"

      # Move window to kanban workspace (manual override)
      "SUPER SHIFT, I, movetoworkspacesilent, special:kanban-init"
      "SUPER SHIFT, P, movetoworkspacesilent, special:kanban-progress"
      "SUPER SHIFT, R, movetoworkspacesilent, special:kanban-review"
      "SUPER SHIFT, D, movetoworkspacesilent, special:kanban-done"
    ];

    # Animation settings for smooth transitions
    animations = {
      animation = [
        "windows, 1, 2, easeOutExpo, slide"
        "windowsIn, 1, 2, easeOutExpo, slide 80%"
        "windowsOut, 1, 2, easeInExpo, slide 80%"
        "workspaces, 1, 2, easeOutExpo, slide"
      ];
    };
  };
}
