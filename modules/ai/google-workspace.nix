{ den, inputs, ... }:

let
  googleWorkspaceSkillsRoot = inputs.googleworkspace-cli + "/skills";

  # Expose only the Workspace capabilities we use, on either side of the aspect.
  gwsSkillNames = [
    "gws-shared"
    "gws-calendar"
    "gws-calendar-agenda"
    "gws-calendar-insert"
    "gws-gmail"
    "gws-gmail-read"
    "gws-gmail-reply"
    "gws-gmail-send"
    "gws-gmail-triage"
    "gws-people"
    "gws-tasks"
  ];

  # Triage defaults to the inbox instead of every unread message.
  gmailTriageText =
    builtins.replaceStrings
      [
        "description: \"Gmail: Show unread inbox summary (sender, subject, date).\""
        "    cliHelp: \"gws gmail +triage --help\""
        "Show unread inbox summary (sender, subject, date)"
        "Show unread inbox summary"
        "gws gmail +triage --help"
        "gws gmail +triage\n```"
        "```bash\ngws gmail +triage\n"
        "| `--query` | — | — | Gmail search query (default: is:unread) |"
        "gws gmail +triage --max 5 --query 'from:boss'"
        "gws gmail +triage --format json | jq '.[].subject'"
        "gws gmail +triage --labels"
      ]
      [
        "description: \"Gmail: Show inbox summary (sender, subject, date).\""
        "    cliHelp: \"gws gmail +triage --query 'in:inbox' --help\""
        "Show inbox summary (sender, subject, date)"
        "Show inbox summary"
        "gws gmail +triage --query 'in:inbox' --help"
        "gws gmail +triage --query 'in:inbox'\n```"
        "```bash\ngws gmail +triage --query 'in:inbox'\n"
        "| `--query` | — | — | Gmail search query (recommended: in:inbox) |"
        "gws gmail +triage --max 5 --query 'in:inbox from:boss'"
        "gws gmail +triage --query 'in:inbox' --format json | jq '.[].subject'"
        "gws gmail +triage --query 'in:inbox' --labels"
      ]
      (builtins.readFile (googleWorkspaceSkillsRoot + "/gws-gmail-triage/SKILL.md"));

  skillDirs =
    pkgs:
    pkgs.lib.genAttrs gwsSkillNames (
      name:
      if name == "gws-gmail-triage" then
        pkgs.writeTextDir "SKILL.md" gmailTriageText
      else
        googleWorkspaceSkillsRoot + "/${name}"
    );
  cli = pkgs: inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.gws;
in
{
  den.aspects.google-workspace = {
    desktop.provides.to-users.homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = [ (cli pkgs) ];
        codyos.harness.skills = lib.mapAttrs (_: toString) (skillDirs pkgs);
      };

    # Hermes also adds extraPackages to the user's packages, so the desktop
    # harness on the same host can use this CLI and should see the same skills.
    hermes.includes = [ den.aspects.google-workspace.desktop ];
    hermes.provides.to-users.homeManager =
      { pkgs, lib, ... }:
      {
        services.hermes-agent.extraPackages = [ (cli pkgs) ];
        codyos.hermes-agent.skills.skillPacks = [
          {
            name = "google-workspace-tools";
            root = pkgs.linkFarm "hermes-agent-google-workspace-skills" (
              lib.mapAttrsToList (name: path: {
                name = "tools/${name}";
                inherit path;
              }) (skillDirs pkgs)
            );
            mode = "managed";
          }
        ];
      };
  };
}
