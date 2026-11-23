# Den conventions

Rules and recipes for agents working in `modules/`. The human-facing overview is [The Den layout](../docs/src/den-native-layout.md).

## Conventions

- **An underscore means "not a Den module".** import-tree loads every `.nix` file except those under a `_` path. Those hold plain NixOS and Home Manager modules, hardware files, packages and data, and their aspect imports them. `default.nix` is allowed only under `_` paths (`check-imports` enforces this).
- **Every-host features include themselves** with `den.default.includes = [ den.aspects.<feature> ];` in their own file. Host files never list them. To find their declarations, use `rg 'den.default.includes' modules`.
- **Fixed host selection belongs in the owning feature file:** `den.aspects.<host>.includes = [ den.aspects.<feature> ];`. Keep `den.schema` for typed facts and global policies, such as the Prometheus target collector, not for testing `host.name` to select features.
- **A cross-host feature is one file with one aspect per side:** `nfs.server` / `nfs.client`, `paperless` / `paperless.scanner`, `opencode` / `opencode.remote`. Select each side in the feature file. Including a parent does not include its children.
- **An aspect is the unit of inclusion; a file is the unit of reading.** Make a separate aspect only when it needs to be included independently. Keep files at roughly 30–250 lines. One aspect can span a directory (`graphical/`, `apps/`). Group a feature's `includes`, `nixos`, and `provides.to-users.homeManager` contributions under one aspect definition per file, using only the paths it needs. `provides.to-users.homeManager` routes the feature's Home Manager settings to the host's users.
- **Host facts live on the host:** `channel`, `localAi`, `lan`, `tailscale`, `mac`, `hardwareConfig`, `nvidiaPowerLimit` in `den.hosts.x86_64-linux.<host>`. Use a plain aspect attrset when no Den context is needed. Request `host` to read host facts and `user` only when the aspect actually needs user context; don't infer host facts from `networking.hostName`. `channel` alone selects stable or unstable nixpkgs, Home Manager and nixvim (`channels.nix`).
- **Shared facts are in `codyos.site`** (`modules/site.nix`): domain, user, LAN and per-host addresses.
- **A service keeps everything next to it:** secrets, nginx vhost, firewall rules, Homepage card and backup paths.
- **Agent skills ship with their tool**, in the aspect that installs the tool.
- **`modules/defaults.nix`** holds only settings that belong to no feature.
- **Keep feature selection independent of include order.** When order matters to a service, enforce it on the affected option, not on the host include.
- **The host names `beast` and `nas` are load-bearing:** `update`, `nightly-build.nix` and `_plugins/lsp.nix` name them.
- **Keep state versions host-local:** `system.stateVersion` in the host's `nixos` block and `home.stateVersion` in its `provides.to-users.homeManager` block.
- **Flake outputs** are `flake.<output>` definitions in `modules/flake/`. There is no flake-parts.

To add a feature, create `modules/<area>/<feature>.nix` defining `den.aspects.<feature>` and register it in the same file. To add a host, see [`new-machine.md`](../docs/src/new-machine.md).

## Focused evaluation and tracing

Three questions need three tools:

- **What does this aspect do with these inputs?** Evaluate a small fixture with only the dependencies it needs. The NFS example below uses Den's internal `aspects.resolve`, pinned in `flake.lock`. It is a debugging recipe, not a stable API.
- **How did this aspect get here?** Trace the real host's Den composition. Filter by aspect chain and class. Keep the non-contributing rows when a contribution is missing.
- **What did the real host get?** Query the merged option, for example `nix eval --json .#nixosConfigurations.nas.config.services.nfs.server.enable`. No closure build is needed for that question.

Run the recipe from the repository root; stage new files first. To trace OpenCode on both hosts instead, change the `--apply` selector to `'examples: examples.opencodeTrace'`.

```bash
nix eval --offline --no-write-lock-file --impure --json \
  --apply 'examples: examples.nfsFixture' --expr "$(cat <<'NIX'
let
  f = builtins.getFlake (toString ./.);
  inputs = f.inputs // { self = f; };
  den = (inputs.nixpkgs.lib.evalModules {
    modules = [ inputs.den.flakeModule (inputs.import-tree (f.outPath + "/modules")) ];
    specialArgs = { inherit inputs; };
  }).config.den;

  fixture = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      (den.lib.aspects.resolve "nixos" den.aspects.nfs.server)
      ({ lib, ... }: {
        options.codyos.site.lan.subnet = lib.mkOption { type = lib.types.str; };
        config.codyos.site.lan.subnet = "192.0.2.0/24";
      })
    ];
  };

  trace = name: let
    host = den.hosts.x86_64-linux.${name};
    captured = den.lib.capture.captureWithPathsWith {
      classes = [ "nixos" "homeManager" ];
      root = den.lib.resolveEntity "host" { inherit host; };
      ctx = { inherit host; };
    };
  in map (e: {
    inherit (e) name class hasClass excluded replacedBy;
    chain = e."aspect-chain";
  }) (builtins.filter (e: e.name == "opencode" || builtins.elem "opencode" e."aspect-chain")
    captured.entries);
in {
  nfsFixture = {
    enabled = fixture.config.services.nfs.server.enable;
    exportsUseFixtureSubnet = inputs.nixpkgs.lib.hasInfix "192.0.2.0/24"
      fixture.config.services.nfs.server.exports;
    port2049 = builtins.elem 2049 fixture.config.networking.firewall.allowedTCPPorts;
  };
  opencodeTrace = { nas = trace "nas"; beast = trace "beast"; };
}
NIX
)"
```

All three fixture fields are `true`. In the trace, look for contributing rows (`hasClass` and not `excluded`): `opencode` for NixOS and Home Manager on the NAS, and the Home Manager routes for `opencode.remote` and `opencode.desktop` on beast. If an input is not cached, rerun without `--offline`.

### Den resolution graphs

For a route too complex for trace rows, [den-diagram](https://github.com/denful/den-diagram) renders the same capture as Mermaid. It is not a CodyOS input; see the [upstream example](https://github.com/denful/den/blob/v0.20.0/docs/src/content/docs/tutorials/case-study-diagrams.mdx). Pass the capture's `entries` and `ctxTrace` to `diagram.context`, then the graph to `diagram.toMermaid`. The graph shows configuration resolution, not runtime state.

### Declared host capabilities

To plan or audit, list the declared units and containers for `nas` or `beast`:

```bash
nix eval --json .#nixosConfigurations.nas.config --apply 'c:
  let hm = c.home-manager.users.codyt; in
  builtins.mapAttrs (_: builtins.attrNames) {
    services = c.systemd.services;
    timers = c.systemd.timers;
    userServices = hm.systemd.user.services;
    userTimers = hm.systemd.user.timers;
    containers = c.virtualisation.oci-containers.containers;
  }'
```

A declared unit may not be running. Confirm on the host.
