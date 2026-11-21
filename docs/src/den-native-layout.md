# The Den layout

CodyOS follows the [dendritic pattern](https://github.com/mightyiam/dendritic): the configuration is organized by feature, not by machine. [Den](https://github.com/denful/den) grew out of that pattern and adds its own aspect and context machinery; CodyOS uses Den to build both hosts.

## How it differs from plain NixOS

| | Plain NixOS | CodyOS |
| --- | --- | --- |
| Unit of configuration | A module per host or role, imported by `configuration.nix` | An *aspect* per feature (`den.aspects.<feature>`) |
| Turn a feature on | `services.<x>.enable = true` | Add the aspect to the host's `includes` list |
| Home Manager | A second tree, wired by hand | The same aspect, in its `homeManager` half |
| A feature on every host | Imported by each host | The feature adds itself to `den.default.includes` |
| "Why is this on the NAS?" | Follow the imports by hand | Den traces which aspect brought it, and by which route |

A host file is short: its facts (channel, addresses, hardware) and the list of features it includes.

## Why aspects

Aspects make the configuration a graph of what happens on each machine. Features are the nodes. Includes, and routes such as host → user, are the edges. Den can resolve that graph, so a person or an agent can:

- ask which feature put a service, package or setting on a host, and through which route;
- evaluate one feature alone, without the rest of the host.

That makes the system legible and testable for the agents that work on it.

## What this changes for you

- **Add or remove a feature on a machine:** change one line in [`modules/hosts/<host>.nix`](../../modules/hosts).
- **A service is in one place:** its secrets, web address, firewall rules, Homepage card and backup paths are in its own file.
- **A tool arrives complete:** the package, its configuration and the agent skill that teaches agents to use it come from one aspect.
- **Both sides of a cross-machine feature are in one file:** NFS server and client, Paperless and the beast scanner, OpenCode and its remote client. Each host includes its side.
- **A new machine is a list of existing features.** See [Installing a new machine](new-machine.md).

## How the files fit together

```mermaid
flowchart TD
    flake["flake.nix<br/>inputs + import-tree ./modules"]

    subgraph hosts["modules/hosts/"]
        nas["nas.nix<br/>facts and the includes list"]
        channels["channels.nix<br/>channel → nixpkgs, Home Manager, nixvim"]
        hw["_nas-hardware.nix"]
    end

    subgraph feature["modules/ai/llama-swap/ (one feature)"]
        aspect["llama-swap.nix<br/>den.aspects.llama-swap"]
        impl["_impl/<br/>the service module"]
        models["_nas-models.nix<br/>this repo's model choices"]
    end

    shared["site.nix, nix/, shell/, …<br/>add themselves to every host"]
    out["modules/flake/<br/>overlay, packages, checks"]
    pkgs["packages/&lt;name&gt;/package.nix"]

    flake -- "loads every file<br/>not under a _ path" --> nas
    flake --> aspect & shared & out
    nas -- "channel = stable" --> channels
    nas -- "imports" --> hw
    nas -- "includes" --> aspect
    aspect -- "imports" --> impl & models
    out -- "overlay turns into pkgs.&lt;name&gt;" --> pkgs
```

Files under a `_` path are loaded only when the owning aspect imports them. For editing conventions and tracing recipes, see [`modules/AGENTS.md`](../../modules/AGENTS.md).
