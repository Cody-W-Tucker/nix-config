{
  den.aspects.harness.homeManager =
    {
      config,
      host,
      inputs,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      qmdEnv = {
        QMD_LLAMA_GPU = "vulkan";
        VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
      };
      karakeepMcp = pkgs.writeShellApplication {
        name = "karakeep-mcp";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          export KARAKEEP_API_ADDR="https://karakeep.${osConfig.codyos.site.domain}"
          KARAKEEP_API_KEY="$(< ${config.sops.secrets.karakeep-api-key.path})"
          export KARAKEEP_API_KEY
          exec npx -y @karakeep/mcp "$@"
        '';
      };
    in
    {
      sops.secrets.karakeep-api-key = { };

      programs.mcp = {
        enable = true;
        servers = {
          karakeep.command = lib.getExe karakeepMcp;
          qmd =
            if host.localAi then
              {
                command = lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd;
                args = [ "mcp" ];
                env = qmdEnv;
              }
            else
              {
                command = lib.getExe pkgs.openssh;
                args = [
                  "-T"
                  "-o"
                  "BatchMode=yes"
                  "nas"
                  "env ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "${n}=${v}") qmdEnv)} qmd mcp"
                ];
              };
          exa.url = "https://mcp.exa.ai/mcp";
          context7.command = lib.getExe pkgs.context7-mcp;
          gh_grep.url = "https://mcp.grep.app";
          nixos-option-search.command = lib.getExe pkgs.mcp-nixos;
        };
      };
    };
}
