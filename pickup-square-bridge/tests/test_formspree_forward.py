"""App callers are forwarded to Formspree. The website is not. HTTP is mocked."""

from __future__ import annotations

import os
import sqlite3

import pytest

import app as bridge
import store


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(bridge, "FORMSPREE_WEBHOOK_SECRET", "")
    monkeypatch.delenv("APP_API_KEY", raising=False)
    bridge.app.config["TESTING"] = True
    return bridge.app.test_client()


class FormspreeResponse:
    def __init__(self, ok=True, payload=None, status_code=200):
        self.ok = ok
        self.status_code = status_code
        self._payload = payload

    def json(self):
        return self._payload

ORIGIN = "https://www.crystalcleandrycleaner.com"
PAGE = "https://www.crystalcleandrycleaner.com/request-pickup.html"


def payload(**overrides):
    body = {
        "name": "Test Customer",
        "phone": "6465551234",
        "email": "test@example.com",
        "address": "400 E 87th Street, New York, NY 10128",
        "address_line2": "Apt 4B",
        "when": "Tomorrow 10am",
        "notes": "Buzz 4B",
    }
    body.update(overrides)
    return body


def fake_square(calls):
    def _fake(method, path, body=None):
        calls.append((method, path, body))
        if path == "/orders":
            return {
                "order": {
                    "id": "ord_1",
                    "reference_id": body["order"]["reference_id"],
                    "state": "OPEN",
                }
            }
        return {"order": {"id": "ord_1", "state": "COMPLETED"}}

    return _fake


def test_website_origin_does_not_forward_even_with_app_key(client, monkeypatch, formspree_calls):
    calls = []
    monkeypatch.setattr(bridge, "square_request", fake_square(calls))
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(source="app"),
        headers={"Origin": ORIGIN, "X-App-Key": "shared-secret"},
    )
    body = resp.get_json()
    assert resp.status_code == 200
    assert body["ok"] is True
    assert body["square_ok"] is True
    assert body["notify_ok"] is None
    assert body["reference_id"].startswith("web-pickup-")
    assert calls[0][2]["order"]["reference_id"] == body["reference_id"]
    assert formspree_calls == []
    saved = store.list_pickups(include_tests=True)
    assert saved[0]["source"] == "web"
    assert saved[0]["reference_id"] == body["reference_id"]
    assert saved[0]["notify_ok"] is None


def test_app_key_gets_app_prefix_and_forwards_in_form_order(client, monkeypatch, formspree_calls):
    calls = []
    monkeypatch.setattr(bridge, "square_request", fake_square(calls))
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    monkeypatch.setenv("FORMSPREE_FORM_URL", "https://formspree.io/f/example")
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(),
        headers={"X-App-Key": "shared-secret"},
    )
    body = resp.get_json()
    assert body["ok"] is True
    assert body["square_ok"] is True
    assert body["notify_ok"] is True
    assert body["reference_id"].startswith("app-pickup-")
    assert calls[0][2]["order"]["reference_id"] == body["reference_id"]
    assert len(formspree_calls) == 1
    forwarded = formspree_calls[0]
    assert forwarded["url"] == "https://formspree.io/f/example"
    assert [name for name, _value in forwarded["data"]] == list(bridge.FORM_FIELD_ORDER)
    assert "is_test" not in dict(forwarded["data"])
    assert forwarded["headers"]["Accept"] == "application/json"
    assert forwarded["headers"]["Origin"] == PAGE
    assert forwarded["headers"]["Referer"] == PAGE
    assert "User-Agent" not in forwarded["headers"]
    saved = store.list_pickups(include_tests=True)
    assert saved[0]["source"] == "app"
    assert saved[0]["notify_ok"] is True
    assert saved[0]["reference_id"].startswith("app-pickup-")


def test_app_test_marks_subject_and_does_not_double_prefix(client, monkeypatch, formspree_calls):
    def forbid_square(*_args, **_kwargs):
        raise AssertionError("Square was called")

    monkeypatch.setattr(bridge, "square_request", forbid_square)
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(name="[TEST] Ada", is_test=True),
        headers={"X-App-Key": "shared-secret", "X-Test": "1"},
    )
    body = resp.get_json()
    assert body["ok"] is True
    assert body["test"] is True
    assert body["square_ok"] is True
    assert body["notify_ok"] is True
    assert body["reference_id"].startswith("test-")
    fields = formspree_calls[0]["data"]
    assert [name for name, _value in fields[:7]] == list(bridge.FORM_FIELD_ORDER)
    assert dict(fields)["name"] == "[TEST] Ada"
    assert fields[-1] == ("_subject", "[TEST] Pickup request \u2014 please ignore")
    assert "\u2014" in bridge.TEST_SUBJECT


def test_app_test_prefixes_a_plain_name(client, monkeypatch, formspree_calls):
    def forbid_square(*_args, **_kwargs):
        raise AssertionError("Square was called")

    monkeypatch.setattr(bridge, "square_request", forbid_square)
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    client.post(
        "/webhooks/formspree-pickup",
        json=payload(name="Ada", is_test=True),
        headers={"X-App-Key": "shared-secret"},
    )
    assert dict(formspree_calls[0]["data"])["name"] == "[TEST] Ada"
    assert formspree_calls[0]["url"] == "https://formspree.io/f/mjgewqpz"


def test_formspree_failure_is_visible_and_still_accepts_the_ticket(client, monkeypatch, formspree_calls):
    monkeypatch.setattr(bridge, "square_request", fake_square([]))
    monkeypatch.setenv("APP_API_KEY", "shared-secret")

    def failed(url, data, headers, timeout=20):
        formspree_calls.append({"url": url})
        return FormspreeResponse(ok=False, payload={"ok": False, "error": "spam"}, status_code=422)

    monkeypatch.setattr(bridge, "post_formspree", failed)
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(name="Alert Miss"),
        headers={"X-App-Key": "shared-secret"},
    )
    body = resp.get_json()
    assert resp.status_code == 200
    assert body["ok"] is True
    assert body["square_ok"] is True
    assert body["notify_ok"] is False
    saved = store.list_pickups(include_tests=True)
    assert saved[0]["notify_ok"] is False
    monkeypatch.setenv("OWNERS_PASSWORD", "shop-secret")
    monkeypatch.setenv("OWNERS_SESSION_SECRET", "signing-secret")
    client.post("/owners/login", data={"password": "shop-secret"})
    page = client.get("/owners").get_data(as_text=True)
    assert "Alert Miss" in page
    assert "Alert failed" in page


def test_formspree_exception_is_not_a_fake_success(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", fake_square([]))
    monkeypatch.setenv("APP_API_KEY", "shared-secret")

    def exploded(*_args, **_kwargs):
        raise OSError("formspree down")

    monkeypatch.setattr(bridge, "post_formspree", exploded)
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(),
        headers={"X-App-Key": "shared-secret"},
    )
    body = resp.get_json()
    assert body["ok"] is True
    assert body["square_ok"] is True
    assert body["notify_ok"] is False


def test_square_failure_does_not_forward(client, monkeypatch, formspree_calls):
    def boom(*_args, **_kwargs):
        raise RuntimeError("SQUARE_ACCESS_TOKEN and SQUARE_LOCATION_ID are required")

    monkeypatch.setattr(bridge, "square_request", boom)
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(),
        headers={"X-App-Key": "shared-secret"},
    )
    assert resp.status_code == 502
    body = resp.get_json()
    assert body["ok"] is False
    assert body["square_ok"] is False
    assert body["notify_ok"] is None
    assert formspree_calls == []


def test_existing_rows_keep_their_ids_when_notify_column_is_added():
    path = os.environ["SQLITE_PATH"]
    conn = sqlite3.connect(path)
    conn.execute(
        """
        CREATE TABLE pickup_requests (
            reference_id TEXT PRIMARY KEY,
            order_id TEXT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL DEFAULT '',
            address TEXT NOT NULL,
            address_line2 TEXT NOT NULL DEFAULT '',
            pickup_when TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            source TEXT NOT NULL,
            is_test INTEGER NOT NULL DEFAULT 0,
            done INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        INSERT INTO pickup_requests (
            reference_id, order_id, name, phone, email, address, address_line2,
            pickup_when, notes, source, is_test, done, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            "web-pickup-kept0001",
            "ord_old",
            "Old Customer",
            "6465559999",
            "",
            "1 Main",
            "",
            "Tomorrow",
            "",
            "web",
            0,
            0,
            "2020-01-01T00:00:00+00:00",
        ),
    )
    conn.commit()
    conn.close()
    rows = store.list_pickups(include_tests=True)
    assert rows[0]["reference_id"] == "web-pickup-kept0001"
    assert rows[0]["order_id"] == "ord_old"
    assert rows[0]["name"] == "Old Customer"
    assert rows[0]["notify_ok"] is None
