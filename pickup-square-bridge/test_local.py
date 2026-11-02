#!/usr/bin/env python3
"""Post a fake Formspree payload to a running bridge (local or Docker)."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

URL = os.environ.get("BRIDGE_URL", "http://127.0.0.1:3015/webhooks/formspree-pickup")

payload = {
    "form": "mjgewqpz",
    "keys": ["name", "phone", "email", "address", "address_line2", "when", "notes"],
    "submission": {
        "_date": "2026-07-13T20:00:00",
        "name": "Test Customer",
        "phone": "6465551234",
        "email": "test@example.com",
        "address": "400 E 87th Street, New York, NY 10128",
        "address_line2": "Apt 4B",
        "when": "Tomorrow 10am",
        "notes": "Buzz 4B — bridge sandbox test",
    },
}


def main() -> int:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        URL,
        data=data,
        method="POST",
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode()
            print(resp.status, body)
            return 0
    except urllib.error.HTTPError as e:
        print(e.code, e.read().decode(), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
