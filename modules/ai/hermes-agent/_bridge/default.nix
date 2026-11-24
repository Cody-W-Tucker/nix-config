# Home Manager side of the NAS bridge: QMD and Cody's local tools.
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
  # Cody's notes, with the index on the NAS's GPU (Vulkan, NVIDIA ICD).
  systemd.user.services.qmd-mcp =
    service "QMD search over Cody's notes, for Hermes"
      "${lib.getExe llmAgents.qmd} mcp --http --host 127.0.0.1 --port ${toString endpoints.qmd.port}"
      {
        QMD_LLAMA_GPU = "vulkan";
        VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
      };

  home.sessionVariables.DEJA_HERMES_HOME = hermesHome;

  # These came onto codyt's PATH through Hermes's packages. Beast's harness
  # runs `qmd mcp` here over SSH; the harness skills below use crm-cli and
  # the workflow CLI (installed system-wide by the workflow module).
  home.packages = [
    llmAgents.qmd
    pkgs.crm-cli
  ];
  codyos.harness.skills = {
    crm-cli = "${pkgs.crm-cli.src}/skills/SKILL.md";
    verified-work-run = "${inputs.workflow}/skills/operational/verified-work-run";
  };

  # Fetching Hermes's inbox branches (from beast over SSH, or here) reads a
  # repository the hermes user owns.
  programs.git.settings.safe.directory = codyosClone;
}
