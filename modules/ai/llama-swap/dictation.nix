{ den, ... }:
let
  endpoint = import ./_endpoint.nix;
in
{
  den.aspects.beast.includes = [ den.aspects.llama-swap.dictation ];

  den.aspects.llama-swap.dictation.provides.to-users.homeManager =
    { lib, pkgs, ... }:
    let
      wtypeFixedKeycodes = pkgs.wtype.overrideAttrs (oa: {
        postPatch = (oa.postPatch or "") + ''
          substituteInPlace main.c \
            --replace-fail 'wtype->keyboard, 0, cmd->single_key_code,' 'wtype->keyboard, 0, cmd->single_key_code + 29,' \
            --replace-fail 'key_code = text_keycodes[(key_code - 1) % ARRAY_SIZE(text_keycodes)];' 'key_code = text_keycodes[(key_code - 1) % ARRAY_SIZE(text_keycodes)];
          } else {
            key_code += 29;' \
            --replace-fail ': wtype->keymap_len + 9;' ': wtype->keymap_len + 38;' \
            --replace-fail 'text_keycodes[i - first] : i + 1;' 'text_keycodes[i - first] : i + 30;'
        '';
      });

      llamaDictate = pkgs.writeShellApplication {
        name = "llama-dictate";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.gnused
          pkgs.jq
          pkgs.libnotify
          pkgs.pipewire
          pkgs.rofi
          wtypeFixedKeycodes
        ];
        text = ''
          base_url="http://${endpoint.host}:${toString endpoint.port}"
          history_url="http://${endpoint.host}:${toString endpoint.speechHistoryPort}"
        ''
        + builtins.readFile ./dictation.sh;
      };
    in
    {
      codyos.workarounds.wtype-keycodes = {
        reason = "wtype 0.5 still sends control-range keycodes for mixed text and key commands, so wtypeFixedKeycodes patches them.";
        upstream = "https://github.com/atx/wtype/pull/74";
        reviewBy = "2027-02-27";
        obsolete = lib.versionAtLeast pkgs.wtype.version "0.6";
      };

      home.packages = [ llamaDictate ];
    };
}
