{ pkgs }:

pkgs.writeShellScriptBin "web-search" ''
  declare -A URLS

  URLS=(
    ["🔍 Google"]="https://www.google.com/search?q="
    ["🧠 Perplexity"]="https://www.perplexity.ai/search/?q="
    ["📦 Nix Options"]="https://mynixos.com/search?q="
    ["🗃️ Hoarder"]="https://hoarder.homehub.tv/dashboard/search?q="
    ["📚 Wikipedia"]="https://en.wikipedia.org/wiki/Special:Search?search="
    ["🎥 YouTube"]="https://www.youtube.com/results?search_query="
  )

  gen_list() {
    printf "%s\n" "''${!URLS[@]}"
  }

  main() {
    platform=$(gen_list | ${pkgs.rofi}/bin/rofi -dmenu -i -l 6 -p 'Select Search Platform' -no-custom)

    if [[ -n "$platform" ]]; then
      query=$(${pkgs.rofi}/bin/rofi -dmenu -p 'Enter Search Query' -l 0)

      if [[ -n "$query" ]]; then
        url="''${URLS[$platform]}$(${pkgs.jq}/bin/jq -sRr @uri <<< "$query")"
        ${pkgs.xdg-utils}/bin/xdg-open "$url"
      fi
    fi
  }

  main
''
