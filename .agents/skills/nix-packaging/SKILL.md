---
name: nix-packaging
description: Package new software or update existing packages using Nix
---

# Overview

Create new Nix packages or update existing ones, with language-specific examples and guidance.

## Workflow: Creating a New Package

1. Identify the software source: internal to this repo or external (e.g., a GitHub repository).
2. Determine the programming language(s) used.
3. Analyze the software structure (build system, dependencies, configuration files).
4. Create the package following language-specific guidance below.
5. Optionally, integrate the package into the current project (e.g., add to overlay and expose via `packages` in `flake.nix`).
6. Test iteratively: run `nix build .#<package-name>`, read errors, fix issues, and rebuild until successful.

## Repository Package Structure

All custom packages live in `packages/<package-name>/` with a consistent structure:

```
packages/
  <package-name>/
    default.nix    # Entry point that calls `callPackage` on package.nix
    package.nix      # The actual package definition (optional if defined in default.nix)
```

### `default.nix` template

```nix
{ pkgs }:

pkgs.callPackage ./package.nix { }
```

This structure makes packages self-contained and ready to import from anywhere in the repository using `pkgs.callPackage ./path/to/packages/<package-name> { }`. The flake's nixpkgs is passed through automatically via `callPackage`.

## Exposing Packages via Flake Output

Add packages to `flake.nix` so they're buildable with `nix build .#<package-name>` and accessible throughout your configuration:

```nix
# In flake.nix outputs
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
in
{
  packages.${system} = {
    headroom-ai = pkgs.callPackage ./packages/headroom-ai { };
    rlm-cli = pkgs.callPackage ./packages/rlm-cli { };
  };
}
```

## Using Packages in Modules

Pass `self` through `specialArgs` so modules can access `self.packages`:

**In flake.nix:**

```nix
let
  specialArgs = { inherit inputs self; };
in
nixosConfigurations.myhost = inputs.nixpkgs.lib.nixosSystem {
  inherit system specialArgs;
  # ...
};
```

**For Home Manager modules, also add to extraSpecialArgs:**

```nix
home-manager.extraSpecialArgs = { inherit inputs self; };
```

**In service modules:**

```nix
{ config, lib, pkgs, self, ... }:

let
  myPackage = self.packages.${pkgs.system}.my-package;
in
{
  # Use myPackage in your configuration
}
```

## Workflow: Updating an Existing Package

Typically, update the `version` and source fetching attributes (e.g., `fetchFromGitHub`). The `hash` field must also be updated using one of these methods:

**Method 1: Calculate the new hash directly**

```bash
# Get the hash
nix-prefetch-url --type sha256 --unpack https://github.com/owner/repo/archive/refs/tags/v<NEW_VERSION>.tar.gz
# Convert to SRI format
nix hash convert --hash-algo sha256 <old-hash>
```

**Method 2: Let Nix tell you the hash**
Set `hash = "";` and run the build. The error message will display the correct hash.

For language-specific update steps, see the references below.

# Language-Specific Packaging Skills

- [Python](./python/python.md) - Packaging Python modules
- [Rust](./rust/rust.md) - Packaging Rust applications
- [JavaScript/TypeScript](./js/js.md) - Packaging npm applications
