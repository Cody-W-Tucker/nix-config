{ pkgs }:

pkgs.writeShellScriptBin "rofi-launcher" ''
  if pgrep -x "rofi" > /dev/null; then
    # Rofi is running, kill it
    pkill -x rofi
    exit 0
  fi

  # Options for rofi menu
  options="Run Program\nWeb Scraper"

  # Capture the selected option in a variable
  selected=$(echo -e "$options" | rofi -dmenu -p "Select:")

  case "$selected" in
    "Run Program")
      rofi -show drun -show-icons
      ;;
    "Web Scraper")
      url=$(rofi -dmenu -p "Enter URL:")
      
      # Check if URL is empty
      if [ -z "$url" ]; then
        notify-send "No URL entered. Web scraper not executed."
        exit 1
      fi

      # Now run the web-scraper with the provided URL
      WEBSCRAPER_PATH="$(command -v web-scraper)"
      if [ -z "$WEBSCRAPER_PATH" ]; then
        notify-send "Web scraper not found in PATH!"
        exit 1
      fi

      $WEBSCRAPER_PATH "$url" && notify-send "Web scraper executed" "File saved successfully!"
      ;;
    *)
      notify-send "No option selected."
      ;;
  esac
''
