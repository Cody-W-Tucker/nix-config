{ pkgs }:

pkgs.writeShellScriptBin "web-search" ''
#!/usr/bin/env bash
  if pgrep -x "rofi" > /dev/null; then
    # Rofi is running, kill it
    pkill -x rofi
    exit 0
  fi

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
    for i in "''${!URLS[@]}"
    do
      echo "$i"
    done
  }

  main() {
    platform=$( (gen_list) | ${pkgs.rofi}/bin/rofi -dmenu -i -l 7 -p 'Select Search Platform' -no-custom -theme-str 'imagebox { enabled: false; width: 0px; }')

    if [[ -n "$platform" ]]; then
      query=$(${pkgs.rofi}/bin/rofi -dmenu -p 'Enter Search Query' -l 0 -theme-str 'imagebox { enabled: false; width: 0px; } window { height: 200px; }')
      base_url=''${URLS[$platform]}

      if [[ -n "$query" ]]; then
        # Properly encode query including spaces
        url=''${base_url}$(${pkgs.jq}/bin/jq -Rr @uri <<< "$query")
      else
        # Extract base domain (handles URLs with paths/parameters)
        protocol="''${base_url%%://*}"
        domain_path="''${base_url#*://}"
        domain="''${domain_path%%[/?]*}"
        url="$protocol://$domain/"
      fi

      ${pkgs.xdg-utils}/bin/xdg-open "$url"
    fi
  }

  main
''
