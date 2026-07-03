# Custom packages and agent skills

This is an index page for two related owners:

- Local packages and operator scripts: [packages/README.md](../packages/README.md)
- Agent packaging recipes and examples: [.agents/skills/nix-packaging/SKILL.md](../.agents/skills/nix-packaging/SKILL.md)

Keep the boundary clean:

- `packages/README.md` owns the package tree that ships with CodyOS.
- `.agents/skills/nix-packaging/` owns agent instructions, templates, and examples for creating or updating packages.

Do not duplicate package implementation notes or agent skill recipes here. Add detail to the local owner instead, then keep this page as the pointer.
