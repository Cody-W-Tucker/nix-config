# `inbox`: agents leave Cody a one-line note about friction in the Discord
# #inbox channel through a channel webhook. Hermes does not watch the channel;
# Cody picks notes up, or @mentions Hermes on one.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inbox = pkgs.writeShellApplication {
    name = "inbox";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      if [[ $# -gt 0 ]]; then
        note="$*"
      else
        note="$(cat)"
      fi
      if [[ -z "''${note//[[:space:]]/}" ]]; then
        echo "usage: inbox <note>  (or pipe the note on stdin)" >&2
        exit 2
      fi

      # Discord rejects messages over 2000 characters.
      content="$(printf '%s\n— %s on %s' "$note" "''${INBOX_FROM:-agent}" "$(uname -n)" | head -c 1990)"

      jq -n --arg content "$content" \
        '{content: $content, username: "inbox", allowed_mentions: {parse: []}}' |
        curl -fsS -o /dev/null -H 'Content-Type: application/json' --data-binary @- \
          "$(< ${config.sops.secrets."discord-inbox-webhook".path})"
      echo "noted"
    '';
  };
in
{
  sops.secrets."discord-inbox-webhook" = { };

  home.packages = [ inbox ];
  codyos.harness.skills.inbox = ./SKILL.md;
}
