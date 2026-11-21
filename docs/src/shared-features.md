# What every host gets

Some features apply to every machine. Each one registers itself in `den.default.includes` from its own file, not from the host files. To list them all from the repository root:

```bash
nix eval --impure --json --expr 'let f = builtins.getFlake (toString ./.); inputs = f.inputs // { self = f; }; ev = inputs.nixpkgs.lib.evalModules { modules = [ inputs.den.flakeModule (inputs.import-tree ./modules) ]; specialArgs = { inherit inputs; }; }; in map (a: a.name or "?") ev.config.den.default.includes'
```

The last five names are Den's own policies.

| Feature | What it does |
| --- | --- |
| [`site`](../../modules/site.nix) | Declares `codyos.site`: domain, user, LAN and per-host addresses |
| [`secrets`](../../modules/secrets.nix) | sops-nix and the private `nixos-secrets` flake |
| [`nix`](../../modules/nix/nix.nix) | Flakes, binary caches, the private-flake access token, garbage collection, store optimisation, `command-not-found` and the `update` shortcuts. `nix/overlay` adds this repo's packages to nixpkgs. |
| [`hardware-baseline`](../../modules/hardware/baseline.nix) | Boot loader policy, redistributable firmware and `fwupd`, Intel microcode, swap |
| [`networking`](../../modules/networking/networking.nix) | NetworkManager, Tailscale, nftables, hardened SSH and fail2ban |
| [`logging`](../../modules/observability/logging.nix) | System logging |
| [`shell`](../../modules/shell/shell.nix) | zsh and the command-line tools |
| [`git`](../../modules/shell/git.nix) | Git, the user's identity, delta, GitHub CLI and lazygit |
| [`home-manager`](../../modules/users/home-manager.nix) | The user account and its Home Manager setup |
| [`nixvim`](../../modules/editor/nixvim.nix) | Neovim, matched to the host's channel |
| [`harness`](../../modules/harness/harness.nix) | Claude Code, the OpenCode client, shared MCP servers, plugins and skills |
| [`research-state`](../../modules/ai/research-state.nix) | The `research-state` tool |
| [`nginx`](../../modules/web/nginx.nix) | The `mkNginxVhost` helper. The web server is `nginx/server`, on the NAS only. |
| [`homepage/cards`](../../modules/web/homepage.nix) | Lets any service declare a dashboard card without turning the dashboard on |

Settings that belong to no feature, such as the time zone, live in [`defaults.nix`](../../modules/defaults.nix).

