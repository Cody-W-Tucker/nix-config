---
name: den-trace
description: Trace how a CodyOS Den aspect reaches a host or user, test an aspect in isolation with fixture inputs, draw its resolution graph, or list the units and containers a host declares. Use when Den inclusion or routing is unclear, or when planning or auditing what a host runs.
---

# Den trace

Three questions, three tools:

| Question | Tool |
| --- | --- |
| What does this aspect do with these inputs? | Fixture: resolve the aspect alone into a small `nixosSystem` |
| How did this aspect get to this host? | Trace: `den.lib.capture.captureWithPathsWith` on the real host |
| What did the host actually get? | `nix eval --json .#nixosConfigurations.<host>.config.<option>` |

A fixture does not prove a real host selects the aspect. A trace or graph does not prove merged values or runtime state.

## Fixture and trace

Run from the repository root; `git add` new files first. The fixture uses Den's internal `aspects.resolve`, pinned in `flake.lock`: a debugging recipe, not a stable API. Change the `--apply` selector to `'examples: examples.opencodeTrace'` for the trace.

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

All three fixture fields are `true`. In the trace, contributing rows have `hasClass` and not `excluded`: `opencode.web` for NixOS and Home Manager on the NAS, and Home Manager routes for `opencode.remote` and `opencode.desktop` on beast. Filter by aspect chain and class, and keep non-contributing rows when a contribution is missing. If an input is not cached, rerun without `--offline`.

## Resolution graph

For a route too tangled for trace rows, [den-diagram](https://github.com/denful/den-diagram) renders the same capture as Mermaid. It is not a CodyOS input; see the [upstream example](https://github.com/denful/den/blob/v0.20.0/docs/src/content/docs/tutorials/case-study-diagrams.mdx). Pass the capture's `entries` and `ctxTrace` to `diagram.context`, then the graph to `diagram.toMermaid`.

## What a host declares

To plan or audit a host, list its declared units and containers:

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

Declared is not running. Confirm on the host with `systemctl` (`--user` for user units) before relying on a unit.
