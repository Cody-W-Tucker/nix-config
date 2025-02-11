{ pkgs }:

# TODO: get obsidian to work (XDG magic): ["🟪 Obsidian"]="obsidian://search?vault=your_vault_name&query="

pkgs.writeShellScriptBin "web-search" ''
  declare -A URLS

  URLS=(
    ["🔍 Google"]="https://www.google.com/search?q="
    ["🧠 Perplexity"]="https://www.perplexity.ai/search/?q="
    ["🗃️ Hoarder"]="https://hoarder.homehub.tv/dashboard/search?q="
    ["❄️ Nix Options"]="https://mynixos.com/search?q="
    ["💻 GitHub"]="https://github.com/search?q="
    ["🎥 YouTube"]="https://www.youtube.com/results?search_query="
    ["📚 Wikipedia"]="https://en.wikipedia.org/wiki/Special:Search?search="
  )

  gen_list() {
    printf "%s\n" "''${!URLS[@]}"
  }

  main() {
    # Select platform
    platform=$(printf "%s\n" "''${!URLS[@]}" | ${pkgs.rofi}/bin/rofi -dmenu -i -l 7 -p 'Platform' -no-custom)
    [[ -z "$platform" ]] && exit 1  # Exit if no platform selected

    # Enter query (remove '-multi-select' to handle spaces as a single input)
    query=$(${pkgs.rofi}/bin/rofi -dmenu -p 'Query' -l 0 | xargs)
    base_url="''${URLS[$platform]}"

    # Encode query and open URL
    if [[ -n "$query" ]]; then
      url="''${base_url}$(echo "$query" | ${pkgs.jq}/bin/jq -sRr @uri)"
    else
      url="''${base_url%%\?*}"  # Remove existing query params if no input
    fi

    ${pkgs.xdg-utils}/bin/xdg-open "$url"
  }

  main
''
