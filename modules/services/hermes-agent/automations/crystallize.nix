{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.codyos.hermes-agent.automations.crystallize;
  hermesAgent = config.services.hermes-agent;
  caPackages = inputs.cognitive-assistant.packages.${pkgs.stdenv.hostPlatform.system} or { };
  hasCrystallize = caPackages ? crystallize;
  crystallizePackage = if hasCrystallize then caPackages.crystallize else null;

  repositoryPath =
    if cfg.repositoryPath != null then
      cfg.repositoryPath
    else
      "${config.codyos.hermes-agent.locations.projectsRoot}/Cognitive-Assistant";

  outputPath =
    if cfg.outputPath != null then
      cfg.outputPath
    else
      "${repositoryPath}/workspaces/${cfg.profile}/data/crystallization.json";

  harvestScript = pkgs.writeShellApplication {
    name = "hermes-crystallize-harvest";
    runtimeInputs = [ pkgs.python3 ] ++ lib.optional hasCrystallize crystallizePackage;
    text = ''
            set -euo pipefail

            export HERMES_HOME="${hermesAgent.stateDir}/.hermes"
            export OVERLAYS_DIR="$HERMES_HOME/skills/external-overlays"
            export OUTPUT_PATH="${outputPath}"
            INPUT_JSON="$(mktemp)"
            export INPUT_JSON

            trap 'rm -f "$INPUT_JSON"' EXIT

            mkdir -p "$(dirname "$OUTPUT_PATH")"

            ${pkgs.python3}/bin/python <<'PY' > "$INPUT_JSON"
      import json
      import os
      from pathlib import Path

      overlays_dir = Path(os.environ["OVERLAYS_DIR"])

      boilerplate = """# Local Amendments

      Record Hermes-specific adjustments for this external skill here instead of
      editing the upstream skill snapshot.

      - Add durable clarifications, caveats, and operator preferences here.
      - Prefer appending new notes over rewriting the generated SKILL.md wrapper.""".strip()

      adaptations = []
      if overlays_dir.exists():
          for amendment_path in sorted(overlays_dir.rglob("references/hermes-local-amendments.md")):
              text = amendment_path.read_text(encoding="utf-8").strip()
              if not text or text == boilerplate:
                  continue

              content = text
              if text.startswith(boilerplate):
                  content = text[len(boilerplate):].strip()
              if not content:
                  continue

              skill_name = amendment_path.parent.parent.name
              rel_source = amendment_path.relative_to(overlays_dir)
              adaptations.append(
                  {
                      "id": f"hermes-skill-{skill_name}",
                      "type": "skill_amendment",
                      "source": f"hermes-local-amendments:{rel_source}",
                      "observed_need": f"Hermes required a durable local amendment for {skill_name}.",
                      "precision_weight": 0.9,
                      "status": "confirmed",
                      "proposed_update": {
                          "target": "skill",
                          "skill": skill_name,
                          "action": "prepend",
                          "content": content,
                      },
                  }
              )

      print(json.dumps({"adaptations": adaptations}, indent=2))
      PY

            adaptation_count="$(${pkgs.python3}/bin/python - <<'PY'
      import json
      import os
      from pathlib import Path

      payload = json.loads(Path(os.environ["INPUT_JSON"]).read_text(encoding="utf-8"))
      print(len(payload.get("adaptations", [])))
      PY
            )"

            echo "Hermes crystallization harvest found $adaptation_count adapted skills"

            crystallize --input "$INPUT_JSON" --output "$OUTPUT_PATH"
    '';
  };
in
{
  options.codyos.hermes-agent.automations.crystallize = {
    enable = lib.mkEnableOption "deterministic Hermes skill crystallization harvest";

    profile = lib.mkOption {
      type = lib.types.str;
      default = "operational";
      description = "Cognitive Assistant profile to write crystallization data for.";
    };

    repositoryPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Writable Cognitive Assistant checkout path. Defaults under the Hermes projects root.";
    };

    outputPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Explicit crystallization artifact path. Defaults inside the Cognitive Assistant checkout.";
    };

    schedule = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "*-*-* 07:15:00"
        "*-*-* 23:15:00"
      ];
      description = "Systemd OnCalendar schedule for deterministic crystallization harvests.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hasCrystallize;
        message = "Hermes crystallization automation requires inputs.cognitive-assistant.packages.<system>.crystallize.";
      }
      {
        assertion = cfg.profile == "operational";
        message = "The current exported crystallize package only supports the default operational profile in automation.";
      }
    ];

    systemd.services.hermes-agent-crystallize-harvest = {
      description = "Harvest Hermes skill amendments into Cognitive Assistant crystallization";
      after = [
        "network-online.target"
        "hermes-agent.service"
      ];
      wants = [
        "network-online.target"
        "hermes-agent.service"
      ];

      environment = {
        HOME = hermesAgent.stateDir;
        HERMES_HOME = "${hermesAgent.stateDir}/.hermes";
      };

      serviceConfig = {
        Type = "oneshot";
        User = hermesAgent.user;
        Group = hermesAgent.group;
        WorkingDirectory = hermesAgent.workingDirectory;
        ExecStart = "${harvestScript}/bin/hermes-crystallize-harvest";
        UMask = "0007";
      };
    };

    systemd.timers.hermes-agent-crystallize-harvest = {
      description = "Run deterministic Hermes crystallization harvest";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };
  };
}
