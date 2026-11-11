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
5. Integrate it: `git add` the new directory. The shared overlay exposes it as `pkgs.<package-name>` and as the flake output `.#<package-name>` automatically.
6. Test iteratively: run `nix build .#<package-name>`, read errors, fix issues, and rebuild until successful. If the NAS uses it, also build it against the NAS's stable nixpkgs (see `packages/README.md`).

## Repository Package Structure

All custom packages live in `packages/<package-name>/`, one directory per package, the same shape nixpkgs uses for `pkgs/by-name`:

```
packages/
  <package-name>/
    package.nix      # A plain callPackage function; the only entry point
    ...              # Helper files it needs (package-lock.json, patches)
```

Do not add a `default.nix` wrapper. `overlays/default.nix` discovers every `packages/<name>/package.nix` with `lib.packagesFromDirectoryRecursive`, and `flake.nix` exports the same set as `packages.x86_64-linux`, so there is no list to maintain. The directory name becomes the attribute name, so check it does not shadow an existing nixpkgs package.

### `package.nix` template

```nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  # Other local packages are ordinary arguments, e.g. `acpx`.
}:

stdenv.mkDerivation {
  # ...
}
```

## Using Packages in Modules

Use `pkgs.<package-name>` in NixOS and Home Manager modules (Home Manager shares the system `pkgs` via `useGlobalPkgs`):

```nix
{ lib, pkgs, ... }:

{
  systemd.services.my-service.serviceConfig.ExecStart = lib.getExe pkgs.my-package;
}
```

Do not use `self.packages.${system}.<name>` or `callPackage ./path/to/packages/<name>` in modules: both bypass the host's nixpkgs and build a second copy of the package.
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
