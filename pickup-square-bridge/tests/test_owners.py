"""Owners board tests. Square is mocked; nothing is posted to Formspree."""

from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

import pytest

import app as bridge
import owners
import store

ORIGIN = "https://www.crystalcleandrycleaner.com"


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(bridge, "FORMSPREE_WEBHOOK_SECRET", "")
    monkeypatch.delenv("APP_API_KEY", raising=False)
    monkeypatch.setenv("OWNERS_PASSWORD", "shop-secret")
    monkeypatch.setenv("OWNERS_SESSION_SECRET", "signing-secret")
    bridge.app.config["TESTING"] = True
    return bridge.app.test_client()


def payload(**overrides):
    body = {
        "name": "Ada Lovelace",
        "phone": "6465551234",
        "email": "ada@example.com",
        "address": "400 E 87th Street, New York, NY 10128",
        "address_line2": "Apt 4B",
        "when": "Tomorrow 10am",
        "notes": "Buzz 4B",
    }
    body.update(overrides)
    return body


def forbid_square(*_args, **_kwargs):
    raise AssertionError("Square was called")


def test_owners_stays_closed_until_configured(client, monkeypatch):
    monkeypatch.delenv("OWNERS_PASSWORD", raising=False)
    monkeypatch.delenv("OWNERS_SESSION_SECRET", raising=False)
    resp = client.get("/owners")
    assert resp.status_code == 503
    assert resp.headers["X-Robots-Tag"] == "noindex, nofollow"
    assert resp.headers["Cache-Control"] == "no-store"
    assert b"noindex" in resp.data
    assert b"Ada Lovelace" not in resp.data


def test_login_and_board_hide_tests_until_toggled(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    web = client.post(
        "/webhooks/formspree-pickup",
        json=payload(name="Web Test", is_test=True),
        headers={"Origin": ORIGIN},
    )
    assert web.status_code == 200
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    app_resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(name="App Test", phone="2125550000", is_test=True),
        headers={"X-App-Key": "shared-secret", "X-Test": "1"},
    )
    assert app_resp.status_code == 200

    denied = client.get("/owners")
    assert denied.status_code == 200
    assert b"Shop password" in denied.data
    assert b"Web Test" not in denied.data

    bad = client.post("/owners/login", data={"password": "nope"})
    assert bad.status_code == 401

    good = client.post("/owners/login", data={"password": "shop-secret"})
    assert good.status_code == 303
    assert good.location.endswith("/owners")
    cookie = good.headers["Set-Cookie"]
    assert "HttpOnly" in cookie
    assert "Path=/owners" in cookie
    assert "Secure" not in cookie

    hidden = client.get("/owners")
    assert hidden.status_code == 200
    assert b"Web Test" not in hidden.data
    assert b"App Test" not in hidden.data
    assert b"Show test requests" in hidden.data
    assert hidden.headers["Cache-Control"] == "no-store"

    shown = client.get("/owners?tests=1")
    text = shown.get_data(as_text=True)
    assert "Web Test" in text and "App Test" in text
    assert "Website" in text and "App" in text
    assert text.count("Test") >= 2
    assert "tel:+16465551234" in text
    assert "maps.google.com" in text
    assert "Apt 4B" in text


def test_square_order_is_stored_for_the_website(client, monkeypatch):
    def fake_square(method, path, body=None):
        if path == "/orders":
            return {
                "order": {
                    "id": "ord_1",
                    "reference_id": body["order"]["reference_id"],
                    "state": "OPEN",
                }
            }
        return {"order": {"id": "ord_1", "state": "COMPLETED"}}

    monkeypatch.setattr(bridge, "square_request", fake_square)
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(name="Real Customer"),
        headers={"Origin": ORIGIN},
    )
    assert resp.status_code == 200
    reference = resp.get_json()["reference_id"]
    client.post("/owners/login", data={"password": "shop-secret"})
    page = client.get("/owners").get_data(as_text=True)
    assert "Real Customer" in page
    assert "ord_1" in page
    assert reference in page
    saved = store.list_pickups(include_tests=False)
    assert saved[0]["source"] == "web"
    assert saved[0]["order_id"] == "ord_1"
    assert saved[0]["is_test"] is False


def test_mark_done_requires_session_and_groups_today(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    now = datetime.now(timezone.utc)
    store.save_pickup(
        reference_id="web-pickup-today1111",
        order_id=None,
        name="Today Person",
        phone="6465551111",
        email="",
        address="1 Main Street",
        address_line2="",
        pickup_when="ASAP",
        notes="",
        source="web",
        is_test=False,
        created_at=now.isoformat(),
    )
    store.save_pickup(
        reference_id="web-pickup-older2222",
        order_id=None,
        name="Earlier Person",
        phone="6465552222",
        email="",
        address="2 Main Street",
        address_line2="",
        pickup_when="Next week",
        notes="",
        source="app",
        is_test=False,
        created_at=(now - timedelta(days=3)).isoformat(),
    )
    client.post("/owners/login", data={"password": "shop-secret"})
    page = client.get("/owners").get_data(as_text=True)
    assert page.index("Today Person") < page.index("Upcoming")
    assert page.index("Upcoming") < page.index("Earlier Person")

    csrf = re.search(r'name="csrf" value="([^"]+)"', page).group(1)
    blocked = client.post(
        "/owners/web-pickup-today1111/done",
        data={"csrf": "nope", "done": "1"},
    )
    assert blocked.status_code == 400

    moved = client.post(
        "/owners/web-pickup-today1111/done",
        data={"csrf": csrf, "done": "1"},
    )
    assert moved.status_code == 303
    after = client.get("/owners").get_data(as_text=True)
    assert after.index("Done") < after.index("Today Person")
    assert "Undo" in after

    logged_out = bridge.app.test_client()
    lonely = logged_out.post(
        "/owners/web-pickup-today1111/done",
        data={"csrf": csrf, "done": "0"},
    )
    assert lonely.status_code == 303
    assert _done_flag("web-pickup-today1111") is True


def _done_flag(reference_id: str) -> bool:
    rows = store.list_pickups(include_tests=True)
    return next(row["done"] for row in rows if row["reference_id"] == reference_id)


def test_names_are_escaped(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    client.post(
        "/webhooks/formspree-pickup",
        json=payload(name="<script>alert(1)</script>", is_test=True),
        headers={"Origin": ORIGIN},
    )
    client.post("/owners/login", data={"password": "shop-secret"})
    page = client.get("/owners?tests=1").get_data(as_text=True)
    assert "<script>alert(1)</script>" not in page
    assert "&lt;script&gt;" in page


def test_login_rate_limit(client):
    for _ in range(owners.LOGIN_MAX_FAILURES):
        resp = client.post(
            "/owners/login",
            data={"password": "nope"},
            environ_base={"REMOTE_ADDR": "203.0.113.9"},
        )
        assert resp.status_code == 401
    blocked = client.post(
        "/owners/login",
        data={"password": "shop-secret"},
        environ_base={"REMOTE_ADDR": "203.0.113.9"},
    )
    assert blocked.status_code == 429
    other = client.post(
        "/owners/login",
        data={"password": "shop-secret"},
        environ_base={"REMOTE_ADDR": "203.0.113.10"},
    )
    assert other.status_code == 303


def test_group_pickups_uses_eastern_today():
    now = datetime(2026, 7, 15, 18, 0, tzinfo=timezone.utc)
    rows = [
        {"name": "done", "done": True, "created_at": now.isoformat()},
        {"name": "today", "done": False, "created_at": now.isoformat()},
        {
            "name": "older",
            "done": False,
            "created_at": (now - timedelta(days=2)).isoformat(),
        },
    ]
    groups = owners.group_pickups(rows, now=now)
    assert [row["name"] for row in groups["today"]] == ["today"]
    assert [row["name"] for row in groups["upcoming"]] == ["older"]
    assert [row["name"] for row in groups["done"]] == ["done"]
