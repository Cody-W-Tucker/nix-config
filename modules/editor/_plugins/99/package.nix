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

  nvimRequireCheck = "99";
}
