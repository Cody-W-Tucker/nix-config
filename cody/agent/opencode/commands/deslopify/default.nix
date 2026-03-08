{ pkgs, ... }:

let
  desloppify = pkgs.python3Packages.buildPythonPackage rec {
    pname = "desloppify";
    version = "0.9.1";
    format = "wheel";
    src = pkgs.fetchPypi {
      inherit pname version format;
      python = "py3";
      platform = "any";
      sha256 = "2fa4daa7cf198fe2e885c643a7ae177f3c8f491cee816f25330ccfc7830d25c0";
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
