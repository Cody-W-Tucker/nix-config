{ ... }:
{
  # Composition only: catalog plus filtered packs, activation, and validation siblings.
  imports = [
    ./module.nix
    ./default-exclusions.nix
    ./cognitive-assistant.nix
    ./seeded-skills.nix
    ./bundled-skill-policy.nix
    ./default-cleanup.nix
    ./default-validation.nix
    ./business
    ./knowledge
    ./workflow
  ];
}
