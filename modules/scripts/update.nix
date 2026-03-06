{ pkgs }:

let
  checkImports = pkgs.writeShellScriptBin "check-imports" ''
    set -e

    BASE_DIR="/etc/nixos"
    cd "$BASE_DIR"

    echo "Checking for unimported .nix files..."

    # Get all .nix files (excluding lock files)
    ALL_NIX_FILES=$(find . -name "*.nix" -type f | grep -v "flake.lock" | sort)

    # Build a map of all imports using a recursive approach
    declare -A IMPORTED_MAP

    # Function to resolve an import path
    resolve_import() {
      local dir="$1"
      local import_path="$2"
      
      # Resolve relative to the importing file's directory
      local resolved="$dir/$import_path"
      
      # If it's a directory, add /default.nix
      if [ -d "$resolved" ]; then
        resolved="$resolved/default.nix"
      fi
      
      # If no extension, add .nix
      if [[ ! "$resolved" == *.nix ]]; then
        resolved="$resolved.nix"
      fi
      
      # Return relative path if file exists
      if [ -f "$resolved" ]; then
        realpath --relative-to="$BASE_DIR" "$resolved" 2>/dev/null
      fi
    }

    # Function to get imports from a file
    get_imports() {
      local file="$1"
      local dir=$(dirname "$file")
      
      # Extract imports - match patterns like ./file.nix, ./dir, ../dir/file.nix
      # Use a simple pattern that looks for relative paths
      grep -oE '\./[^[:space:];\]\}",]+|\.\./[^[:space:];\]\}",]+' "$file" 2>/dev/null | \
      while read -r import_path; do
        # Clean up the path (remove trailing punctuation)
        import_path=$(echo "$import_path" | sed 's/[;\]\}",]*$//')
        
        # Only process relative imports
        if [[ "$import_path" == ./* || "$import_path" == ../* ]]; then
          resolve_import "$dir" "$import_path"
        fi
      done
    }

    # BFS to trace all imports starting from flake.nix
    trace_imports() {
      local queue="./flake.nix"
      local processed=""
      
      while [ -n "$queue" ]; do
        # Get first item from queue
        local current=$(echo "$queue" | cut -d' ' -f1)
        queue=$(echo "$queue" | cut -d' ' -f2-)
        queue=$(echo "$queue" | sed 's/^ *//')
        
        # Skip if already processed
        if [[ "$processed" == *" $current "* ]]; then
          continue
        fi
        
        # Skip if doesn't exist
        if [ ! -f "$current" ]; then
          continue
        fi
        
        processed="$processed $current "
        IMPORTED_MAP["$current"]=1
        
        # Get imports from this file
        local imports=$(get_imports "$current")
        for imported in $imports; do
          if [[ ! "$processed" == *" $imported "* ]]; then
            queue="$queue $imported"
          fi
        done
      done
      
      echo "$processed"
    }

    ALL_IMPORTED=$(trace_imports)

    # Find unimported files
    UNIMPORTED=""
    for file in $ALL_NIX_FILES; do
      if [[ ! "$ALL_IMPORTED" == *" $file "* ]]; then
        UNIMPORTED="$UNIMPORTED\n  - $file"
      fi
    done

    if [ -n "$UNIMPORTED" ]; then
      echo -e "\nError: The following .nix files are not imported anywhere:$UNIMPORTED"
      echo -e "\nPlease import these files or remove them if they are unused."
      exit 1
    else
      echo "All .nix files are properly imported."
    fi
  '';
in

pkgs.writeShellScriptBin "update" ''
  cd /etc/nixos &&
  nix fmt &&

  # Check for unimported .nix files
  ${checkImports}/bin/check-imports &&

  git add . &&
  if [ -z "$1" ]; then
    echo "Enter commit message:" &&
    read commit_message
    commit_message=''${commit_message:-"Update NixOS configuration"}
  else
    commit_message="$1"
  fi &&
  git commit -m "$commit_message" &&
  sudo nixos-rebuild switch &&
  git push
''
