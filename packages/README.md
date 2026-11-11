# Custom packages

`packages/` owns local Nix package definitions and the small operator scripts that are installed into CodyOS. Put package-specific build details here, close to the derivations, instead of repeating them in `docs/`.

## Layout

Every package is one directory with one entry point, the same shape nixpkgs uses for `pkgs/by-name`:

```
packages/<name>/package.nix   # a plain callPackage function
packages/<name>/...           # helper files it needs (lock files, patches)
```

`overlays/default.nix` discovers these with `lib.packagesFromDirectoryRecursive`, so each directory becomes `pkgs.<name>` on every host, and `nix build .#<name>` builds it. There is no per-package `default.nix` and no list to update.

- Packages are built against the host's own nixpkgs (stable on the NAS, unstable on Beast).
- Depend on another local package by naming it as an argument, like any nixpkgs dependency (`backpass` takes `acpx` and `lavish-axi`).
- Consumers write `pkgs.<name>`. Do not use `callPackage` on a path into `packages/`, and do not use `self.packages`.

```nix
# packages/<name>/package.nix
{
  lib,
  buildNpmPackage,
  fetchzip,
}:

buildNpmPackage {
  # ...
}
```

Keep package directory names in lowercase kebab-case; the directory name is the attribute name. Check that it does not shadow an existing nixpkgs attribute.

## Current packages

### `update` and `check-imports`

Maintenance commands installed into the system environment by `modules/system/scripts.nix`.

- `update` formats the repo, runs `check-imports`, stages changes, prompts for a commit message, rebuilds with `sudo nixos-rebuild switch`, then pushes.
- `check-imports [dir]` checks directories with a `default.nix` (under `/etc/nixos` by default) and reports `.nix` files that are present but not imported, plus imports that point at missing files. It also runs as the `imports` flake check.

Use `check-imports` when adding or moving Nix modules. Use `update` for the normal operator path after changes have settled.

### `crm-cli`

Pinned [crm.cli](https://github.com/dzhng/crm.cli) `v0.3.10`. No upstream flake. The GitHub `bun build --compile` binaries omit `@libsql/linux-x64-gnu`, so this wraps `bun run src/cli.ts` with a fixed-output `bun install`.

- Wired into Hermes via `modules/services/hermes-agent/skills/business` `extraPackages`.
- Database path is `CRM_DB` (Hermes unit: `$HERMES_HOME/crm/crm.db`), not this derivation.

### `kokoro-assets`

Kokoro TTS model files for the llama-swap `kokoro-82m` wrapper (`modules/services/llama-swap/proxy.nix`).

- A `runCommand` derivation assembles `kokoro-v1_0.pth`, the model config, and selected voice profiles into one store path.
- Fetches from HuggingFace with fixed hashes, so the runtime gets a reproducible model directory.
- The spaCy `en_core_web_sm` model that Kokoro's G2P (via misaki) needs comes from nixpkgs (`python3Packages.spacy-models.en_core_web_sm`).

### `backpass`

Pinned [Backpass](https://github.com/kunchenguid/backpass) `v0.1.31` (Node >=22.5) from the npm registry via `buildNpmPackage` with a vendored `package-lock.json`. The wrapper prefixes the nix-built `acpx` and `lavish-axi` onto `PATH` because Backpass shells out to both helpers resolved from `PATH`.

- Only `backpass` is installed, in the desktop user environment (`users/cody/desktop.nix`). `acpx` and `lavish-axi` are private runtime dependencies on the wrapper `PATH`, so `backpass` resolves both without `nix shell` and without installing either helper directly.

### `lavish-axi`

Pinned [lavish-axi](https://github.com/kunchenguid/lavish-axi) `v0.1.31` (Node >=22) from the npm registry via `buildNpmPackage` with a vendored `package-lock.json`. This is the optional Backpass review UI (`lavish-axi` binary, `dist/` ships prebuilt so `dontNpmBuild` is set with `npmPackFlags = [ "--ignore-scripts" ]`).

- Buildable directly as `.#lavish-axi`, but not installed directly; the desktop installs only `backpass`, which bundles this UI on its wrapper `PATH`.

### `acpx`

Pinned [acpx](https://github.com/openclaw/acpx) `v0.19.4` (Node >=22.13) from the npm registry via `buildNpmPackage` with a vendored `package-lock.json`. No pre-existing package in any pinned flake input, so it is packaged here. `dist/` ships prebuilt, so `dontNpmBuild` is set and `npmPackFlags = [ "--ignore-scripts" ]` keeps the install hook from running the upstream `prepack` tsdown rebuild.

## Adding or changing a package

1. Create `packages/<name>/package.nix` as a `callPackage` function, and `git add` it (flakes only see tracked files).
2. Use it as `pkgs.<name>` from the module that consumes it. For a system operator command, add it to `modules/system/scripts.nix`.
3. Build it: `nix build .#<name>`. For packages used on the NAS, also build the NAS variant, since it uses stable nixpkgs: `nix build --impure --expr '(builtins.getFlake "/etc/nixos").nixosConfigurations.nas.pkgs.<name>'`.

Agent-facing packaging recipes live in `.agents/skills/nix-packaging/`. Do not copy those examples here; this README owns the local `packages/` tree and points agents/operators to the package files that actually ship.
