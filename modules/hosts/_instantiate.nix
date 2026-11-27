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
