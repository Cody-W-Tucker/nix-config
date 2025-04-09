{ pkgs }:

pkgs.writeShellScriptBin "web-search" ''
  #!/usr/bin/env bash

  declare -A URLS=(
    ["🔍 Google"]="https://www.google.com/search?q="
    ["🧠 Perplexity"]="https://www.perplexity.ai/search/?q="
    ["🗃️ Hoarder"]="https://hoarder.homehub.tv/dashboard/search?q="
    ["❄️ Nix Options"]="https://mynixos.com/search?q="
    ["💻 GitHub"]="https://github.com/search?q="
    ["🎥 YouTube"]="https://www.youtube.com/results?search_query="
    ["📚 Wikipedia"]="https://en.wikipedia.org/wiki/Special:Search?search="
  )

  gen_list() {
    for platform in "''${!URLS[@]}"; do
      echo -en "$platform\0info\x1f''${URLS[$platform]}\n"
    done
  }

  handle_selection() {
    platform="$1"
    base_url="''${URLS[$platform]}"
    query="$ROFI_TEXT"  # Use the text from rofi's input bar

    if [[ -n "$query" ]]; then
      url="''${base_url}$(echo "$query" | ${pkgs.jq}/bin/jq -Rr @uri)"
    else
      url="$base_url"
    fi
    ${pkgs.xdg-utils}/bin/xdg-open "$url"
  }

  # Rofi script mode logic
  case "$ROFI_RETV" in
    0) gen_list ;;                # Initial call: show the list
    1) handle_selection "$1" ;;   # Selection made: process with input bar text
  esac
''