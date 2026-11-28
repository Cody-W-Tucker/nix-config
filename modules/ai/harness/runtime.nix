{
  den.aspects.harness.homeManager =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      inherit (llmPkgs) rtk;
      tools = with pkgs; [
        bash
        coreutils
        diffutils
        direnv
        findutils
        gawk
        git
        gnugrep
        gnused
        jq
        nix
        nix-diff
        nodejs
        nvd
        python3
        ripgrep
        rtk
      ];
      bashExe = lib.getExe pkgs.bash;
      direnvExe = lib.getExe pkgs.direnv;
      run = pkgs.writeShellScript "agent-project-shell" ''
        export PATH=${lib.makeBinPath tools}''${PATH:+:"$PATH"}
        exec ${direnvExe} exec . ${bashExe} --noprofile --norc "$@"
      '';
      shell = lib.getExe (
        pkgs.writeShellScriptBin "bash" ''
          # Shell detection must still work when the working directory has a blocked .envrc.
          case "''${1-}" in
            --version|--help) exec ${bashExe} "$@" ;;
          esac
          # Unload any environment inherited from the launching terminal before setting
          # the baseline PATH. direnv exec does not change the working directory.
          if [[ -n ''${DIRENV_DIFF-} ]]; then
            exec ${direnvExe} exec ${builtins.storeDir} ${run} "$@"
          fi
          exec ${run} "$@"
        ''
      );

      inherit (config.codyos.harness) agentEnvFiles;
      withAgentEnv =
        package:
        if agentEnvFiles == [ ] then
          package
        else
          pkgs.symlinkJoin {
            name = "${lib.getName package}-${lib.getVersion package}";
            paths = [ package ];
            inherit (package) meta;
            postBuild = ''
              rm "$out/bin/${package.meta.mainProgram}"
              cat > "$out/bin/${package.meta.mainProgram}" <<'EOF'
              #!${pkgs.runtimeShell}
              set -a
              ${lib.concatMapStrings (file: ''
                if [ -r "${file}" ]; then . "${file}"; fi
              '') agentEnvFiles}
              set +a
              exec ${lib.getExe package} "$@"
              EOF
              chmod +x "$out/bin/${package.meta.mainProgram}"
            '';
          };

      rtkContext = builtins.readFile ./context/rtk.md;
    in
    {
      options.codyos.harness.agentEnvFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Environment files sourced by OpenCode, Claude Code and Pi, and by nothing else.";
      };

      config = {
        home.packages = [ rtk ];
        xdg.configFile."opencode/plugins/rtk.ts".source = "${rtk}/libexec/rtk/hooks/opencode/rtk.ts";

        programs = {
          opencode = {
            package = withAgentEnv pkgs.unstable.opencode;
            settings.shell = shell;
            context = rtkContext;
          };
          claude-code = {
            package = withAgentEnv llmPkgs.claude-code;
            settings.env.CLAUDE_CODE_SHELL = shell;
            context = rtkContext;
            settings.hooks.PreToolUse = [
              {
                matcher = "Bash";
                hooks = [
                  {
                    type = "command";
                    command = "${rtk}/libexec/rtk/hooks/claude/rtk-rewrite.sh";
                  }
                ];
              }
            ];
          };
          pi-coding-agent = {
            package = withAgentEnv llmPkgs.pi;
            settings.shellPath = shell;
          };
        };
      };
    };
}
