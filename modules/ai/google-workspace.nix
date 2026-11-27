{ den, inputs, ... }:

let
  googleWorkspaceSkillsRoot = inputs.googleworkspace-cli + "/skills";

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

    hermes.includes = [ den.aspects.google-workspace.desktop ];
    hermes.nixos =
      { pkgs, lib, ... }:
      {
        imports = [ ./_gws-token ];
        environment.etc."hermes/starter-skills/google-workspace".source =
          pkgs.linkFarm "hermes-google-workspace-starter-skills"
            (
              lib.mapAttrsToList (name: path: {
                name = "tools/${name}";
                inherit path;
              }) (skillDirs pkgs)
            );
      };
  };
}
