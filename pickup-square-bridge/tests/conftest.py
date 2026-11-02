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
