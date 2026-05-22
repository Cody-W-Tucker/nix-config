import os
from pathlib import Path


def _is_managed(hermes_home: Path) -> bool:
    managed = os.getenv("HERMES_MANAGED", "").strip().lower()
    if managed in {"1", "true", "yes", "on", "nixos", "homebrew"}:
        return True
    return (hermes_home / ".managed").exists()


try:
    import hermes_constants
except Exception:
    hermes_constants = None


if hermes_constants is not None and hasattr(hermes_constants, "secure_parent_dir"):
    _original_secure_parent_dir = hermes_constants.secure_parent_dir

    def secure_parent_dir(path: Path) -> None:
        path = Path(path)

        try:
            hermes_home = hermes_constants.get_hermes_home().resolve()
            parent = path.parent.resolve()
        except Exception:
            _original_secure_parent_dir(path)
            return

        # Managed NixOS installs intentionally share HERMES_HOME between the
        # service account and interactive CLI users via group permissions.
        # Upstream auth helpers call secure_parent_dir() for credential writes,
        # but tightening any directory inside HERMES_HOME to 0700 breaks the
        # shared-runtime model and prevents the CLI from reading .env.
        if _is_managed(hermes_home):
            try:
                parent.relative_to(hermes_home)
            except ValueError:
                pass
            else:
                return

        _original_secure_parent_dir(path)

    hermes_constants.secure_parent_dir = secure_parent_dir
