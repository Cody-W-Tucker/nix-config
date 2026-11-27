{
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  endpoints = import ./endpoints.nix;
  cfg = osConfig.services.hermes-agent;
  hermesHome = "${cfg.stateDir}/.hermes";
  codyosClone = "${cfg.workingDirectory}/codyos";
  service = description: command: environment: {
    Unit.Description = description;
    Service = {
      ExecStart = command;
      Environment = lib.mapAttrsToList (name: value: "${name}=${value}") environment;
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
in
{
  systemd.user.services.qmd-mcp =
    service "QMD search over Cody's notes, for Hermes"
      "${lib.getExe llmAgents.qmd} mcp --http --host 127.0.0.1 --port ${toString endpoints.qmd.port}"
      {
        QMD_LLAMA_GPU = "vulkan";
        VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
      };

  home.sessionVariables.DEJA_HERMES_HOME = hermesHome;

  home.packages = [
    llmAgents.qmd
    pkgs.crm-cli
  ];
  codyos.harness.skills = {
    crm-cli = "${pkgs.crm-cli.src}/skills/SKILL.md";
    verified-work-run = "${inputs.workflow}/skills/operational/verified-work-run";
  };

  programs.git.settings.safe.directory = codyosClone;
}
