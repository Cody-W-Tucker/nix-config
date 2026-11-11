# Repo maintenance commands installed system-wide. The packages themselves
# live in packages/<name>/ and reach pkgs through the shared overlay.
# For user-specific scripts, see users/cody/desktop/packages/scripts/.
{ pkgs, inputs, ... }:

{
  environment.systemPackages = [
    pkgs.check-imports
    pkgs.update
    inputs.workflow.packages.${pkgs.stdenv.hostPlatform.system}.researchState
  ];
}
