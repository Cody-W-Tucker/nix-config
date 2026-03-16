{ pkgs, ... }:

let
  desloppify = pkgs.callPackage ./package.nix { inherit pkgs; };
in
{
  home.packages = [ desloppify ];

  programs.git.ignores = [
    ".desloppify/"
  ];

  programs.opencode.commands = {
    clean-code = ''
      I want you to improve the quality of this codebase. To do this, run desloppify.
      Run ALL of the following:

      desloppify update-skill opencode

      Before scanning, check for directories that should be excluded (vendor, build output, generated code, worktrees, etc.) and exclude each obvious one with the command `desloppify exclude <path>`.
      Share any questionable candidates with me before excluding.

      desloppify scan --path .
      desloppify next

      --path is the directory to scan (use "." for the whole project, or "src/" etc).

      Your goal is to get the strict score as high as possible. The scoring resists gaming — the only way to improve it is to actually make the code better.

      THE LOOP: run `next`. It is the execution queue from the living plan, not the whole backlog. It tells you what to fix now, which file, and the resolve command to run when done. Fix it, resolve it, run `next` again. Over and over. This is your main job.

      Use `desloppify backlog` only when you need to inspect broader open work that is not currently driving execution.

      Don't be lazy. Large refactors and small detailed fixes — do both with equal energy. No task is too big or too small. Fix things properly, not minimally.

      Use `plan` / `plan queue` to reorder priorities or cluster related issues. Rescan periodically.
      The scan output includes agent instructions — follow them, don't substitute your own analysis.
    '';
  };
}
