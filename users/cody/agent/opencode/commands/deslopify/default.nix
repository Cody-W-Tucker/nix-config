{ pkgs, ... }:

let
  desloppify = pkgs.python3Packages.buildPythonPackage rec {
    pname = "desloppify";
    version = "0.9.5"; # Update this to desired version
    pyproject = true;
    nativeBuildInputs = [
      pkgs.python3Packages.setuptools
      pkgs.python3Packages.defusedxml
    ];
    src = pkgs.fetchPypi {
      inherit pname version;
      # Replace old hash with pkgs.lib.fakeHash; rebuild and replace with "hash---"
      sha256 = "sha256-GXaPK0eS38787I5hwsHZ10eSdtI9hLQKyIkeM3OS884=";
    };
  };
in
{
  home.packages = [ desloppify ];

  programs.opencode.commands = {
    clean-code = ''
      I want you to improve the quality of this codebase. To do this, run desloppify.
      Run ALL of the following:

      desloppify update-skill claude

      Before scanning, check for directories that should be excluded (vendor, build output, generated code, worktrees, etc.) and exclude each obvious ones with the command `desloppify exclude <path>`.
      Share any questionable candidates with me before excluding.

      desloppify scan --path .
      desloppify next

      --path is the directory to scan (use "." for the whole project, or "src/" etc).

      Your goal is to get the strict score as high as possible. The scoring resists gaming — the only way to improve it is to actually make the code better.

      THE LOOP: run `next`. It tells you what to fix, which file, and the resolve command to run when done. Fix it, resolve it, run `next` again. Over and over. This is your main job.

      Don't be lazy. Large refactors and small detailed fixes — do both with equal energy. No task is too big or too small. Fix things properly, not minimally.

      Use `plan` to reorder priorities or cluster related issues. Rescan periodically. The scan output includes agent instructions — follow them, don't substitute your own analysis.
    '';
  };
}
