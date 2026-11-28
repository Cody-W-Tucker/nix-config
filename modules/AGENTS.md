# Den conventions

Every `.nix` file here is a Den module defining `den.aspects.*`; [The Den layout](../docs/src/den-native-layout.md) is the overview. Use the `den-trace` skill to see how an aspect reaches a host.

- **Add a feature** as `modules/<area>/<feature>.nix` defining `den.aspects.<feature>`. Group its `includes`, `nixos` and `provides.to-users.homeManager` (the host's users' Home Manager side) under one definition. To add a host, follow [`new-machine.md`](../docs/src/new-machine.md).
- **Inclusion is the on switch, declared in the feature's own file:** `den.aspects.<host>.includes = [ den.aspects.<feature> ];` for one host, `den.default.includes` for every host. Host files never list features. Do not test `host.name` to select features; `den.schema` is for typed facts and global policies.
- **A cross-host feature is one file with one aspect per side:** `nfs.server` / `nfs.client`, `paperless` / `paperless.scanner`, `opencode.web` / `opencode.remote`. Including a parent does not include its children.
- **A `_` path is not a Den module.** import-tree skips it; it holds plain NixOS/Home Manager modules, hardware files, scripts and data that the aspect imports. `default.nix` is allowed only under `_` paths (`check-imports`).
- **Split by inclusion, not size.** Make a separate aspect only when it must be included on its own. Keep files about 30–250 lines; one aspect may span a directory (`graphical/`, `apps/`).
- **Host facts** (`channel`, `localAi`, `lan`, `tailscale`, `mac`, `hardwareConfig`, `nvidiaPowerLimit`) are set in `den.hosts.x86_64-linux.<host>` and read through Den's `host` argument, never from `networking.hostName`. Request `user` only when needed. `channel` alone picks stable or unstable nixpkgs, Home Manager and nixvim.
- **Shared facts** (domain, user, LAN and host addresses) are in `codyos.site` (`site.nix`). Never hardcode them.
- **A service keeps its secrets, nginx vhost, firewall rules, Homepage card and backup registration in its own aspect.** A tool's agent skill ships in the aspect that installs the tool.
- **When order matters, set it on the affected option**, not by include order.
- `system.stateVersion` and `home.stateVersion` stay in the host file. `defaults.nix` holds only settings that belong to no feature. Flake outputs are `flake.<output>` in `flake/`; there is no flake-parts.
- The host names `beast` and `nas` are hard-coded in `update`, `nightly-build.nix` and `_plugins/lsp.nix`.
