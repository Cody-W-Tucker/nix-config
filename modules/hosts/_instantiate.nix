# Shared nixosSystem wrapper for den hosts (plain function, not a Den module).
# Keeps the exact nixosSystem call shape the flake used before Den.
{ inputs }:
nixosSystem: args:
nixosSystem (
  args
  // {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
    };
  }
)
