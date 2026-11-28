This is a minimal environment. Do not assume system-wide installations of languages or external tools.

If direnv finds a project `.envrc` in the working directory or a parent, run project commands there with `direnv exec . <command>`.

If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.
Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

Examples:
- Python: nix shell nixpkgs#python3 --command python script.py
- Node: nix shell nixpkgs#nodejs --command node script.js
