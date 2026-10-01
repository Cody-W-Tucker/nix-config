# Custom packages

`packages/` owns local Nix package definitions and the small operator scripts that are installed into CodyOS. Put package-specific build details here, close to the derivations, instead of repeating them in `docs/`.

## Layout

- `packages/<name>/default.nix` is the public entry point.
- `packages/<name>/package.nix` holds the derivation when the package needs more than a tiny expression.
- `packages/system-scripts/` holds wrapped command-line tools used to maintain this repo.

Prefer the thin `default.nix` pattern:

```nix
{ pkgs, ... }:

pkgs.callPackage ./package.nix { }
```

Keep package files named in lowercase kebab-case. If a package needs helper files, keep them inside that package directory and make the ownership obvious from the file name.

## Current packages

### `system-scripts`

Maintenance commands installed into the system environment.

- `update` formats the repo, runs `check-imports`, stages changes, prompts for a commit message, rebuilds with `sudo nixos-rebuild switch`, then pushes.
- `check-imports` checks directories with a `default.nix` and reports `.nix` files that are present but not imported, plus imports that point at missing files.

Use `check-imports` when adding or moving Nix modules. Use `update` for the normal operator path after changes have settled.

### `crm-cli`

Pinned [crm.cli](https://github.com/dzhng/crm.cli) `v0.3.10`. No upstream flake. The GitHub `bun build --compile` binaries omit `@libsql/linux-x64-gnu`, so this wraps `bun run src/cli.ts` with a fixed-output `bun install`.

- Wired into Hermes via `modules/services/hermes-agent/skills/business` `extraPackages`.
- Database path is `CRM_DB` (Hermes unit: `$HERMES_HOME/crm/crm.db`), not this derivation.

### `kokoro`

Kokoro TTS model bundle and its supporting spaCy model.
Local packaging details:

- `default.nix` uses a `runCommand` derivation to assemble model files into one store path.
- Includes `kokoro-v1_0.pth`, model config, and selected voice profiles.
- Fetches voice assets from HuggingFace so the runtime can consume a fixed, reproducible model directory.
- `en-core-web-sm.nix` packages the spaCy small English model that Kokoro's G2P (via misaki) requires at runtime.

### `backpass`

Pinned [Backpass](https://github.com/kunchenguid/backpass) `v0.1.31` (Node >=22.5) from the npm registry via `buildNpmPackage` with a vendored `package-lock.json`. The wrapper prefixes the nix-built `acpx` and `lavish-axi` onto `PATH` because Backpass shells out to both helpers resolved from `PATH`.

- Only `backpass` is wired into the desktop user environment in `users/cody/desktop/default.nix`; `acpx` and `lavish-axi` are private runtime dependencies on the wrapper `PATH`, so `backpass` resolves both without `nix shell` and without installing either helper directly.

### `lavish-axi`

Pinned [lavish-axi](https://github.com/kunchenguid/lavish-axi) `v0.1.31` (Node >=22) from the npm registry via `buildNpmPackage` with a vendored `package-lock.json`. This is the optional Backpass review UI (`lavish-axi` binary, `dist/` ships prebuilt so `dontNpmBuild` is set with `npmPackFlags = [ "--ignore-scripts" ]`).

- Exposed as `packages.x86_64-linux.lavish-axi` for direct builds, but not installed directly; the desktop installs only `backpass`, which bundles this UI on its wrapper `PATH`.

### `acpx`

Pinned [acpx](https://github.com/openclaw/acpx) `v0.19.4` (Node >=22.13) from the npm registry via `buildNpmPackage` with a vendored `package-lock.json`. No pre-existing package in any pinned flake input, so it is packaged here. `dist/` ships prebuilt, so `dontNpmBuild` is set and `npmPackFlags = [ "--ignore-scripts" ]` keeps the install hook from running the upstream `prepack` tsdown rebuild.

## Adding or changing a package

1. Create `packages/<name>/default.nix`.
2. Move non-trivial build logic into `packages/<name>/package.nix`.
3. Expose the package through the module or package set that consumes it.
4. If it is a system operator command, add it through `packages/system-scripts/default.nix` or the appropriate system package module.
5. Run the smallest relevant check. For import wiring, run `check-imports`. For risky packaging changes, build the specific package or run a dry rebuild for the affected host.

Agent-facing packaging recipes live in `.agents/skills/nix-packaging/`. Do not copy those examples here; this README owns the local `packages/` tree and points agents/operators to the package files that actually ship.
