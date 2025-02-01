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
      query=$(${pkgs.rofi}/bin/rofi -dmenu -p 'Enter Search Query' -l 0 -multi-select)

      if [[ -n "$query" ]]; then
        url="''${URLS[$platform]}$(${pkgs.jq}/bin/jq -sRr @uri <<< "$query")"
        ${pkgs.xdg-utils}/bin/xdg-open "$url"
      fi
    fi
  }

  main
''
