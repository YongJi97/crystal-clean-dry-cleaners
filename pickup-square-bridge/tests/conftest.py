"""Keep each test's pickup database in a temp file."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture(autouse=True)
def isolated_pickup_db(monkeypatch, tmp_path):
    monkeypatch.setenv("SQLITE_PATH", str(tmp_path / "pickups.db"))
    import owners

    owners.reset_login_limits()


class FormspreeResponse:
    def __init__(self, ok=True, payload=None, status_code=200):
        self.ok = ok
        self.status_code = status_code
        self._payload = {"ok": True} if payload is None else payload

    def json(self):
        if isinstance(self._payload, Exception):
            raise self._payload
        return self._payload


@pytest.fixture
def formspree_calls():
    return []


@pytest.fixture(autouse=True)
def block_formspree_network(monkeypatch, formspree_calls):
    """App-key posts forward to Formspree. Tests must never open that socket."""
    import app as bridge

    def fake(url, data, headers, timeout=20):
        formspree_calls.append(
            {"url": url, "data": list(data), "headers": dict(headers), "timeout": timeout}
        )
        return FormspreeResponse()

    def forbid_network(*_args, **_kwargs):
        raise AssertionError("tests must not perform real HTTP")

    monkeypatch.setattr(bridge, "post_formspree", fake)
    monkeypatch.setattr(bridge.requests, "post", forbid_network)
    monkeypatch.setattr(bridge.requests, "request", forbid_network)
