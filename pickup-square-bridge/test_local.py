#!/usr/bin/env python3
"""Post a pickup payload to a running bridge (local or Docker).

By default this is a test request: is_test true and X-Test: 1. The bridge
returns {ok, test, reference_id} and does not create a Square order.

Nothing is sent to Formspree. Test clients that do post to Formspree should
set _subject to a value starting with "[TEST]" (the iOS app sends
"[TEST] Pickup request — please ignore") so the email and Discord alert
are labeled.

Set BRIDGE_LIVE=1 to create a real Square order with the credentials in .env.
That path is for sandbox/production checks Yong runs on purpose.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

URL = os.environ.get("BRIDGE_URL", "http://127.0.0.1:3015/webhooks/formspree-pickup")
LIVE = os.environ.get("BRIDGE_LIVE", "").strip().lower() in {"1", "true", "yes"}

payload: dict = {
    "name": "Test Customer",
    "phone": "6465551234",
    "email": "test@example.com",
    "address": "400 E 87th Street, New York, NY 10128",
    "address_line2": "Apt 4B",
    "when": "Tomorrow 10am",
    "notes": "Buzz 4B — bridge sandbox test",
}

if not LIVE:
    payload["is_test"] = True


def main() -> int:
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if not LIVE:
        headers["X-Test"] = "1"
    app_key = os.environ.get("APP_API_KEY", "").strip()
    if app_key:
        headers["X-App-Key"] = app_key
    elif not os.environ.get("BRIDGE_ORIGIN"):
        # No Origin and no key. If the server has APP_API_KEY set, this 401s.
        print(
            "No APP_API_KEY in the environment. If the bridge requires X-App-Key, export it.",
            file=sys.stderr,
        )

    origin = os.environ.get("BRIDGE_ORIGIN", "").strip()
    if origin:
        headers["Origin"] = origin

    data = json.dumps(payload).encode()
    req = urllib.request.Request(URL, data=data, method="POST", headers=headers)
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
