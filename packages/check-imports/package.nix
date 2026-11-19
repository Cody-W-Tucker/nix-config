{
  writeShellApplication,
  findutils,
  coreutils,
  gnugrep,
  gnused,
}:

writeShellApplication {
  name = "check-imports";
  runtimeInputs = [
    findutils
    coreutils
    gnugrep
    gnused
  ];
  text = ''
    # Check for missing module imports in Nix configurations
    # This script validates that all .nix files in directories with default.nix are properly imported,
    # and that no default.nix exists under modules/ outside `_` paths.

    set -euo pipefail

    # Defaults to the live repo; `nix flake check` passes the flake source.
    cd "''${1:-/etc/nixos}"
    error_count=0

    # Den layout rule: every non-underscore .nix under modules/ is loaded by import-tree as a
    # flake-level module, so a default.nix there is always a mistake (plain NixOS/Home Manager
    # module trees live under `_` paths, where import-tree does not look).
    if [[ -d modules ]]; then
      while IFS= read -r stray; do
        echo "Error: $stray is a default.nix outside a '_' path under modules/"
        error_count=$((error_count + 1))
      done < <(find modules -type f -name default.nix ! -path '*/_*' | sort)
    fi

    mapfile -t defaults < <(find . -type f -name default.nix)

    for default in "''${defaults[@]}"; do
      dir=$(dirname "$default")

      pushd "$dir" >/dev/null

      # Only match imports starting with ./ (not ../ which go to parent dirs)
      mapfile -t imported < <(
        grep -oE '(^|[[:space:]])\./[^ ]+\.nix' default.nix 2>/dev/null | sed 's/^[[:space:]]*//;s#\./##'
      )

      declare -A imp=()
      for m in "''${imported[@]}"; do
        imp["$m"]=1
      done

      mapfile -t locals < <(
        find . -maxdepth 1 -type f -name '*.nix' \
          ! -name default.nix -printf '%f\n' 2>/dev/null
      )

      for f in "''${locals[@]}"; do
        if [[ -z "''${imp[$f]:-}" ]]; then
          echo "Error: Missing import in $default: $f is not imported"
          error_count=$((error_count + 1))
        fi
      done

      for m in "''${imported[@]}"; do
        if [[ ! -f $m ]]; then
          echo "Error: Bad import in $default: $m does not exist"
          error_count=$((error_count + 1))
        fi
      done

      popd >/dev/null
    done

    if ((error_count > 0)); then
      echo "Found $error_count import error(s). Please fix them."
      exit 1
    else
      echo "All imports OK!"
      exit 0
    fi
  '';
}
