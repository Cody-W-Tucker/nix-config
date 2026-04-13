{ pkgs }:

pkgs.writeShellApplication {
  name = "check-imports";
  runtimeInputs = [
    pkgs.findutils
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
  ];
  text = ''
    # Check for missing module imports in Nix configurations
    # This script validates that all .nix files in directories with default.nix are properly imported

    set -euo pipefail

    cd /etc/nixos
    error_count=0

    # Find all default.nix files in the project
    mapfile -t defaults < <(find . -type f -name default.nix)

    # Check each default.nix file for import consistency
    for default in "''${defaults[@]}"; do
      dir=$(dirname "$default")

      pushd "$dir" >/dev/null

      # Extract all relative imports from default.nix (e.g., ./module.nix)
      # Only match imports starting with ./ (not ../ which go to parent dirs)
      # Remove the "./" prefix to get just the filename
      mapfile -t imported < <(
        grep -oE '(^|[[:space:]])\./[^ ]+\.nix' default.nix 2>/dev/null | sed 's/^[[:space:]]*//;s#\./##'
      )

      # Create a lookup table of imported modules for fast checking
      declare -A imp=()
      for m in "''${imported[@]}"; do
        imp["$m"]=1
      done

      # Find all .nix files in current directory (excluding default.nix)
      mapfile -t locals < <(
        find . -maxdepth 1 -type f -name '*.nix' \
          ! -name default.nix -printf '%f\n' 2>/dev/null
      )

      # Check for .nix files that exist but aren't imported
      for f in "''${locals[@]}"; do
        if [[ -z "''${imp[$f]:-}" ]]; then
          echo "Error: Missing import in $default: $f is not imported"
          error_count=$((error_count + 1))
        fi
      done

      # Check for imports that point to non-existent files
      for m in "''${imported[@]}"; do
        if [[ ! -f $m ]]; then
          echo "Error: Bad import in $default: $m does not exist"
          error_count=$((error_count + 1))
        fi
      done

      popd >/dev/null
    done

    # Report results and exit with appropriate status code
    if ((error_count > 0)); then
      echo "Found $error_count import error(s). Please fix them."
      exit 1
    else
      echo "All imports OK!"
      exit 0
    fi
  '';
}
