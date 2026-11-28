The harness uses Bash and provides `python3`, `node`, and standard CLI tools. Do not assume project dependencies are installed.

Set the shell tool's working directory to the project directory. The harness loads its `.envrc` automatically before running each command. If a command changes to another project directory, use `direnv exec . <command>` there or start a new tool call in that directory.

For a missing one-off tool with no project environment, use `nix shell nixpkgs#<package> --command <tool>` instead of installing it globally.
