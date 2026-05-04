{ config, ... }:
{
  services.swaync = {
    enable = true;
    style = ''
      /* Notification action buttons styling */
      .notification-action {
        border-radius: 6px;
        color: @theme_text_color;
        background-color: @theme_bg_color;
        margin: 4px;
        padding: 8px 12px;
        font-size: 14px;
        min-height: 32px;
      }

      .notification-action:hover {
        background-color: shade(@theme_bg_color, 1.1);
      }

      .notification-action:active {
        background-color: shade(@theme_bg_color, 0.9);
      }

      /* Inline reply text entry */
      .inline-reply {
        margin-top: 8px;
        margin-bottom: 4px;
      }

      .inline-reply entry {
        border-radius: 6px;
        padding: 8px;
        background-color: @theme_bg_color;
      }
    '';
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      notification-window-width = 400;
      notification-inline-replies = true;
      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;
      widget-config = {
        title = {
          text = "Notification Center";
          clear-all-button = true;
          button-text = "󰆴 Clear All";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        label = {
          max-lines = 1;
          text = "Notification Center";
        };
        mpris = {
          image-size = 96;
          image-radius = 7;
        };
        volume = {
          label = "󰕾";
        };
        backlight = {
          label = "󰃟";
        };
      };
      notification-visibility = {
        voice-input = {
          # Surpress notification when using speech to text
          state = "ignored";
          summary = "Voice Input";
        };
        kdeconnect-sms = {
          state = "shown";
          app-name = "KDE Connect";
          summary = "Messages";
          timeout = 60;
        };
      };
      widgets = [
        "title"
        "mpris"
        "dnd"
        "notifications"
      ];
    };
  };
}
