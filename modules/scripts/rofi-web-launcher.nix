{ pkgs }:

pkgs.writeShellScriptBin "web-search" ''
  #!/usr/bin/env bash

  # Check if Rofi is already running
  if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
  fi

  # Declare search platforms and their base URLs
  declare -A URLS=(
    ["🔍 Google"]="https://www.google.com/search?q="
    ["🧠 Perplexity"]="https://www.perplexity.ai/search/?q="
    ["🗃️ Hoarder"]="https://hoarder.homehub.tv/dashboard/search?q="
    ["❄️ Nix Options"]="https://mynixos.com/search?q="
    ["💻 GitHub"]="https://github.com/search?q="
    ["🎥 YouTube"]="https://www.youtube.com/results?search_query="
    ["📚 Wikipedia"]="https://en.wikipedia.org/wiki/Special:Search?search="
  )

  # Generate list of search platforms for Rofi
  gen_list() {
    for platform in "''${!URLS[@]}"; do
      echo "$platform"
    done
  }

  # Main function
  main() {
    # Prompt user to select a platform using Rofi
    platform=$(gen_list | rofi -dmenu -i -l 7 -p 'Select Search Platform' -no-custom)

    # If a platform is selected, prompt for a search query
    if [[ -n "$platform" ]]; then
      query=$(rofi -dmenu -p 'Enter Search Query' -l 0)

      # Get the base URL for the selected platform
      base_url="''${URLS[$platform]}"

      if [[ -n "$query" ]]; then
        # Encode the query string properly
        url="''${base_url}$(echo "$query" | jq -Rr @uri)"
      else
        # If no query is entered, open the base URL
        url="$base_url"
      fi

      # Open the URL in the default browser
      xdg-open "$url"
    fi
  }

  main
''
