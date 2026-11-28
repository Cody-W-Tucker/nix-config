{ lib, ... }:
let
  keymap = mode: key: action: desc: {
    inherit mode action;
    key = "<Leader>${key}";
    options = {
      silent = true;
    }
    // lib.optionalAttrs (desc != null) { inherit desc; };
  };
  cmd =
    key: command: desc:
    keymap "n" key "<cmd>${command}<CR>" desc;
  telescope = key: picker: cmd key "Telescope ${picker}" null;
  lua =
    mode: key: module: fn: desc:
    keymap mode key { __raw = ''function() require("${module}").${fn}() end''; } desc;
in
{
  programs.nixvim.keymaps = [
    (telescope "ff" "find_files")
    (telescope "fg" "live_grep")
    (telescope "fb" "buffers")
    (telescope "fh" "help_tags")
    (cmd "gg" "LazyGit" "Open Lazygit")
    (cmd "-" "Yazi" null)
    (cmd "==" "Yazi cwd" null)
    (lua "v" "9v" "99" "visual" "99 Visual")
    (lua "n" "9s" "99" "search" "99 Search")
    (lua [ "n" "v" ] "9x" "99" "stop_all_requests" "99 Stop")
    (lua "n" "9m" "99.extensions.telescope" "select_model" "99 Model")
    (lua "n" "9p" "99.extensions.telescope" "select_provider" "99 Provider")
  ];
}
