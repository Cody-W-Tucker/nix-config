{ inputs, ... }:
{
  # Repo maintenance commands installed system-wide. The packages themselves
  # live in packages/<name>/ and reach pkgs through the shared overlay.
  # For user-specific scripts, see modules/desktop/_scripts/ (modules/desktop/scripts.nix).
  den.aspects.scripts.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.check-imports
        pkgs.update
        (import "${inputs.workflow}/packages.nix" { inherit pkgs; }).researchState
      ];
    };
}
