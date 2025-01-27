{ pkgs }:

pkgs.writeShellScriptBin "web-search" ''
    declare -A URLS

    URLS=(
      ["🌎 Search"]="https://www.google.com/search?q="
    )

    # List for rofi
    gen_list() {
      for i in "''${!URLS[@]}"
      do
        echo "$i"
      done
    }

    main() {
      # Pass the list to rofi
      platform=$( (gen_list) | ${pkgs.rofi}/bin/rofi -dmenu )

      if [[ -n "$platform" ]]; then
        query=$( (echo ) | ${pkgs.rofi}/bin/rofi -dmenu )

        if [[ -n "$query" ]]; then
  	url=''${URLS[$platform]}$query
  	xdg-open "$url"
        else
  	exit
        fi
      else
        exit
      fi
    }

    main

    exit 0
''
