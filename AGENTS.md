# CodyOS Development Guide

## Build Commands
- **Build & switch config**: `update "descriptive commit message"`
- **Format code**: `nix fmt` (included in update script)
- **Check flake**: `nix flake check`

## Code Style Guidelines

### File Structure
- Use `.nix` extension for all Nix files
- Organize modules in `modules/` directory with subdirectories for logical grouping
- Host-specific configs in `hosts/` directory
- User configs in `cody/` directory

### Imports & Dependencies
- List imports alphabetically at file top
- Use relative paths for local modules (`./module.nix`)
- Group imports by type (external, local)

### Formatting
- 2-space indentation
- No semicolons at expression end
- Use descriptive comments with section headers (`# ------------------------`)
- Break long lists with newlines for readability

### Naming Conventions
- Lowercase with hyphens for module names (`client-syncthing.nix`)
- PascalCase for service configurations
- snake_case for environment variables
- Descriptive variable names (avoid abbreviations)

### Error Handling
- Use `pkgs.callPackage` for script packaging
- Validate hardware configurations before committing
- Test configurations on non-production hosts first

### Security
- Store secrets in `secrets/` with SOPS encryption
- Never commit sensitive data or keys
- Use `allowUnfree` predicate carefully

### Testing
- No automated tests currently - manual testing required
- Test configurations with `nixos-rebuild build-vm` for isolated testing
- Validate hardware-specific changes on target machines

### Git Workflow
- Use `update "descriptive message"` for formatted commits, rebuilds, and pushes
- Commit hardware configs separately from software changes
- Pull before rebuild on target machines