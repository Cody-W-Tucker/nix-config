# Catalog only: exactly tmv-sales, builder, research stay parked (no messaging adapters or credentials).
{
  ...
}:
let
  salesBusinessPacks = [
    "crm-tools"
    "google-workspace-tools"
  ];
in
{
  _module.args.salesBusinessPacks = salesBusinessPacks;

  # Invariant: only tmv-sales seeds business packs; builder/research stay empty.
  _module.args.profileDefinitions = {
    tmv-sales = {
      displayName = "TMV Sales";
      description = "TMV sales follow-up over CRM and Google Workspace. Parked profile, no messaging adapters or credentials.";
      mcpAllow = [ "karakeep" ];
      compressionThreshold = 0.70;
      businessPacks = salesBusinessPacks;
      platformToolsets = {
        api_server = [
          "web"
          "search"
          "browser"
          "skills"
          "file"
          "todo"
          "memory"
          "session_search"
          "terminal"
        ];
        cli = [
          "web"
          "search"
          "browser"
          "skills"
          "file"
          "todo"
          "memory"
          "session_search"
          "terminal"
        ];
        cron = [
          "web"
          "search"
          "skills"
          "memory"
        ];
      };
      overlay = ''
        # Profile: tmv-sales

        Sales follow-up for TMV over the local CRM CLI and Google Workspace.
        Evidence-led, concise, no technical/Nix, finance, or recipe scope.
        Uses only the karakeep evidence MCP; nixos, actualBudget, mealie,
        stripe, and code-review-graph are out of scope here.
      '';
      curatedSkills = [
        "bind-to-operator"
        "read-the-active-mode"
        "relational-orientation"
        "decision-calibration"
        "decision-ready-not-impressive"
        "boundary-handoff"
        "redirect-from-analysis-to-action"
        "project-dashboard"
        "earned-candor-and-the-commitment-handoff"
        "separate-fear-from-clarity-and-ownership"
      ];
    };

    builder = {
      displayName = "Builder";
      description = "Technical Nix and code builder over nixos and code-review-graph. Parked profile, no messaging adapters or credentials.";
      mcpAllow = [
        "nixos"
        "code-review-graph"
      ];
      compressionThreshold = 0.70;
      businessPacks = [ ];
      platformToolsets = {
        api_server = [
          "web"
          "search"
          "browser"
          "skills"
          "file"
          "memory"
          "session_search"
          "terminal"
        ];
        cli = "all";
        cron = [
          "web"
          "search"
          "skills"
          "memory"
          "terminal"
        ];
      };
      overlay = ''
        # Profile: builder

        Technical builder for NixOS and code. Uses the nixos option-search
        MCP and code-review-graph only. No sales, finance, or recipe scope:
        no karakeep sales notes, no actualBudget, no mealie, no stripe.
      '';
      curatedSkills = [
        "bound-before-solving"
        "diagnose-before-patching"
        "verify-before-trust"
        "failure-recovery"
        "collapse-unearned-complexity"
        "complexity-reduction"
        "scope-framing"
        "skip-the-default-scripts"
        "additive-thinking-partner"
        "system-building-as-meaning-making"
      ];
    };

    research = {
      displayName = "Research";
      description = "Web and evidence research over karakeep. Parked profile, read-only MCP, no messaging adapters or credentials.";
      mcpAllow = [ "karakeep" ];
      compressionThreshold = 0.65;
      businessPacks = [ ];
      platformToolsets = {
        api_server = [
          "web"
          "search"
          "browser"
          "skills"
          "memory"
          "session_search"
          "terminal"
          "filesystem"
        ];
        cli = [
          "web"
          "search"
          "skills"
          "memory"
          "session_search"
          "terminal"
          "filesystem"
        ];
        cron = [
          "web"
          "search"
          "skills"
          "memory"
          "session_search"
          "terminal"
          "filesystem"
        ];
      };
      overlay = ''
        # Profile: research

        Web and evidence research. Karakeep is the evidence store; no
        mutation-capable MCP (no actualBudget writes, no stripe). Read-only
        posture, cite sources, keep digests tight.
      '';
      curatedSkills = [
        "bound-before-solving"
        "verify-before-trust"
        "mode-detection"
        "scope-framing"
        "complexity-reduction"
        "read-the-active-mode"
        "redirect-from-analysis-to-action"
        "avoidance-vs-misalignment-discriminator"
      ];
    };
  };
}
