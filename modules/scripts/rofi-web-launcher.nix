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
    platform=$(gen_list | ${pkgs.rofi}/bin/rofi -dmenu -i -l 7 -p 'Select Search Platform' -no-custom)

    if [[ -n "$platform" ]]; then
        # Capture and sanitize query input
        query=$(${pkgs.rofi}/bin/rofi -dmenu -p 'Enter Search Query' -l 0 -multi-select | xargs)
        
        # Encode query for safe URL usage
        encoded_query=$(${pkgs.jq}/bin/jq -sRr @uri <<< "$query")
        
        base_url="''${URLS[$platform]}"

        if [[ -n "$query" ]]; then
            # Construct final URL with encoded query
            url="''${base_url}''${encoded_query}"
        else
            # Default to base URL if no query is entered
            protocol="''${base_url%%://*}"
            domain_path="''${base_url#*://}"
            domain="''${domain_path%%[/?]*}"
            url="$protocol://$domain/"
        fi

        # Open the URL in a browser
        ${pkgs.xdg-utils}/bin/xdg-open "$url"
    fi
  }

  main
''
