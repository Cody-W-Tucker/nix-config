# User profiles

`codyt.nix` is the `codyt` user aspect: the account and the Home Manager profile. The editor is in `modules/editor/`, the AI harness in `modules/ai/harness/`, and shell, git and CLI tools in `modules/shell/`.

- A user setting for every host goes in an aspect here that `codyt.nix` includes. A whole feature for every host registers itself in `den.default.includes` in its own file instead.
- Host-specific user settings come from the owning feature's `provides.to-users.homeManager` (`graphical`, `apps`, `opencode.remote`). GUI apps go in `graphical` or `apps`.
- `inputs` comes from `extraSpecialArgs` in `home-manager.nix`.
- A new user is a new aspect, not a special case of Cody's paths.
