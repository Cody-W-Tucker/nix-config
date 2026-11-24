"""Publish a short-lived Google access token without exposing the refresh token."""

import grp
import json
import os
from pathlib import Path
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def refresh(credentials, destination, group):
    data = json.loads(credentials.read_text())
    payload = {key: data[key] for key in ("client_id", "client_secret", "refresh_token")}
    if not all(isinstance(value, str) and value for value in payload.values()):
        raise ValueError("incomplete OAuth credential")
    payload["grant_type"] = "refresh_token"
    request = Request("https://oauth2.googleapis.com/token", urlencode(payload).encode())
    with build_opener(NoRedirect()).open(request, timeout=20) as response:
        token = json.load(response)["access_token"]
    if not isinstance(token, str) or not token or not token.isascii() or not token.isprintable():
        raise ValueError("invalid access token")

    # Bind the directory in bubblewrap, not this file: rename replaces the inode.
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
        source = Path(temporary.name)
        try:
            temporary.write(token.encode())
            temporary.flush()
            os.fchown(temporary.fileno(), 0, grp.getgrnam(group).gr_gid)
            os.fchmod(temporary.fileno(), 0o640)
            source.replace(destination)
        finally:
            source.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        refresh(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
    except HTTPError as error:
        sys.exit(f"Google token refresh failed (HTTP {error.code})")
    except (KeyError, OSError, TypeError, URLError, ValueError):
        sys.exit("Google token refresh failed; check the network and the OAuth credential file")
