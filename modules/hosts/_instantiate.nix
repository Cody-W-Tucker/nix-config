# Shared nixosSystem wrapper for den hosts (plain function, not a Den module).
# Keeps the exact nixosSystem call shape the flake used before Den. Called from
# channels.nix with the channel's nixosSystem and the host entity's `system`
# (Den itself calls `instantiate { modules }` and passes no system argument).
{ inputs }:
{ nixosSystem, system }:
args:
nixosSystem (
  args
  // {
    inherit system;
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
    };
  }
)
