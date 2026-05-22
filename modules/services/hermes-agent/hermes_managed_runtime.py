import os
from pathlib import Path


MANAGED_SHARED_DIR_MODE = 0o2770
MANAGED_SHARED_FILE_MODE = 0o660


def _is_managed(hermes_home: Path) -> bool:
    managed = os.getenv("HERMES_MANAGED", "").strip().lower()
    if managed in {"1", "true", "yes", "on", "nixos", "homebrew"}:
        return True
    return (hermes_home / ".managed").exists()


def _is_managed_subpath(path: Path, hermes_home: Path, relative_prefix: str) -> bool:
    if not _is_managed(hermes_home):
        return False
    try:
        path.resolve().relative_to((hermes_home / relative_prefix).resolve())
    except Exception:
        return False
    return True


def patch_hermes_secure_parent_dir() -> None:
    try:
        import hermes_constants
    except Exception:
        hermes_constants = None

    if hermes_constants is None or not hasattr(hermes_constants, "secure_parent_dir"):
        return

    original_secure_parent_dir = hermes_constants.secure_parent_dir

    def secure_parent_dir(path: Path) -> None:
        path = Path(path)

        try:
            hermes_home = hermes_constants.get_hermes_home().resolve()
            parent = path.parent.resolve()
        except Exception:
            original_secure_parent_dir(path)
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

        original_secure_parent_dir(path)

    hermes_constants.secure_parent_dir = secure_parent_dir


def patch_cron_secure_paths() -> None:
    try:
        import cron.jobs as cron_jobs
    except Exception:
        cron_jobs = None

    if cron_jobs is None or not hasattr(cron_jobs, "_secure_dir") or not hasattr(cron_jobs, "_secure_file"):
        return

    original_cron_secure_dir = cron_jobs._secure_dir
    original_cron_secure_file = cron_jobs._secure_file

    def _cron_hermes_home() -> Path:
        try:
            return cron_jobs.HERMES_DIR.resolve()
        except Exception:
            return Path(os.getenv("HERMES_HOME", "~/.hermes")).expanduser().resolve()

    def _cron_secure_dir(path: Path) -> None:
        path = Path(path)
        hermes_home = _cron_hermes_home()

        if _is_managed_subpath(path, hermes_home, "cron"):
            try:
                os.chmod(path, MANAGED_SHARED_DIR_MODE)
            except Exception:
                pass
            return

        original_cron_secure_dir(path)

    def _cron_secure_file(path: Path) -> None:
        path = Path(path)
        hermes_home = _cron_hermes_home()

        if _is_managed_subpath(path, hermes_home, "cron"):
            try:
                if path.exists():
                    os.chmod(path, MANAGED_SHARED_FILE_MODE)
            except Exception:
                pass
            return

        original_cron_secure_file(path)

    cron_jobs._secure_dir = _cron_secure_dir
    cron_jobs._secure_file = _cron_secure_file


def apply() -> None:
    patch_hermes_secure_parent_dir()
    patch_cron_secure_paths()
