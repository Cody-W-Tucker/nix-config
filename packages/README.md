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

### `en-core-web-sm`

spaCy small English model used by speech and language-processing flows.

Local packaging details:

- Fetches the upstream model wheel directly from the spaCy model release.
- Builds it with `buildPythonPackage`.
- Wires it to the matching `spacy` dependency.

### `kokoro`

Kokoro TTS model bundle.

Local packaging details:

- Uses a `runCommand` derivation to assemble model files into one store path.
- Includes `kokoro-v1_0.pth`, model config, and selected voice profiles.
- Fetches voice assets from HuggingFace so the runtime can consume a fixed, reproducible model directory.

## Adding or changing a package

1. Create `packages/<name>/default.nix`.
2. Move non-trivial build logic into `packages/<name>/package.nix`.
3. Expose the package through the module or package set that consumes it.
4. If it is a system operator command, add it through `packages/system-scripts/default.nix` or the appropriate system package module.
5. Run the smallest relevant check. For import wiring, run `check-imports`. For risky packaging changes, build the specific package or run a dry rebuild for the affected host.

Agent-facing packaging recipes live in `.agents/skills/nix-packaging/`. Do not copy those examples here; this README owns the local `packages/` tree and points agents/operators to the package files that actually ship.
