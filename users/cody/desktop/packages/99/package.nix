{ fetchFromGitHub, vimUtils }:

vimUtils.buildVimPlugin {
  pname = "99";
  version = "unstable-2026-06-11";

  src = fetchFromGitHub {
    owner = "ThePrimeagen";
    repo = "99";
    rev = "c17422457027c913c76c75a921fca1e623d2678e";
    hash = "sha256-iilpiG81kHIv7Y0qvPzZOanNA0lsPotlB18cvtmTy0o=";
  };

  # Upstream HEAD ships lua/99/editor/lsp.lua, which requires a
  # 99.editor.treesitter module that does not exist (its use in
  # editor/init.lua is commented out, so nothing real pulls it in).
  # Scope the require check to the entry module the keymaps use instead
  # of discovery mode, which requires every module and trips on the dead
  # one.
  nvimRequireCheck = "99";
}
