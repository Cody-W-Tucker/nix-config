let
  context = ''
    # Environment

    Unless otherwise stated, you are operating in a NixOS system.

    This is a minimal environment. Do not assume system-wide installations of languages or external tools.

    If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.
    Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

    Examples:
    - Python: nix shell nixpkgs#python3 --command python script.py
    - Node: nix shell nixpkgs#nodejs --command node script.js

    ${builtins.readFile ../../../docs/open-ontologies-mcp.md}
  '';
in
{
  programs.opencode.context = context;
  programs.claude-code.context = context;
}
