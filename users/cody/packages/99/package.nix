{ fetchFromGitHub, vimUtils }:

vimUtils.buildVimPlugin {
  pname = "99";
  version = "unstable-2026-02-21";

  src = fetchFromGitHub {
    owner = "ThePrimeagen";
    repo = "99";
    rev = "3787c3dc34a1a9b818b3e71afa02823f5bec96c3";
    hash = "sha256-BtAHgiMhYOZybqMuYohUgE3i3yYi7/vIBKQgdJij6CM=";
  };
}
