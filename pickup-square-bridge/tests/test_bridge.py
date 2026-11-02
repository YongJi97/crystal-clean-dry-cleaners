"""Bridge tests. Square HTTP is mocked; nothing is posted to Formspree."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import app as bridge  # noqa: E402

ORIGIN = "https://www.crystalcleandrycleaner.com"
OTHER_ORIGIN = "https://crystalcleandrycleaner.com"


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(bridge, "FORMSPREE_WEBHOOK_SECRET", "")
    monkeypatch.delenv("APP_API_KEY", raising=False)
    bridge.app.config["TESTING"] = True
    return bridge.app.test_client()


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


def forbid_square(*_args, **_kwargs):
    raise AssertionError("Square was called")


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


def test_health_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["ok"] is True
    assert body["app_key_configured"] is False


def test_missing_fields(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post("/webhooks/formspree-pickup", json={"name": "Only"})
    assert resp.status_code == 400
    assert resp.get_json()["ok"] is False


def test_is_test_skips_square_and_returns_reference(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(is_test=True),
    )
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["ok"] is True
    assert body["test"] is True
    assert body["reference_id"].startswith("test-")
    assert "order_id" not in body


def test_x_test_header_skips_square(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(),
        headers={"X-Test": "1"},
    )
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["test"] is True
    assert body["reference_id"].startswith("test-")


def test_test_flag_inside_formspree_envelope(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post(
        "/webhook",
        json={"submission": payload(is_test="true")},
    )
    assert resp.status_code == 200
    assert resp.get_json()["test"] is True


def test_live_post_creates_paid_order(client, monkeypatch):
    calls = []
    monkeypatch.setattr(bridge, "square_request", fake_square(calls))
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(),
        headers={"Origin": ORIGIN},
    )
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["ok"] is True
    assert body["order_id"] == "ord_1"
    assert body["order_state"] == "COMPLETED"
    assert body["reference_id"].startswith("web-pickup-")
    assert "test" not in body
    assert calls[0][0] == "POST" and calls[0][1] == "/orders"
    assert calls[1][1] == "/orders/ord_1/pay"
    assert resp.headers["Access-Control-Allow-Origin"] == ORIGIN


def test_disallowed_origin_does_not_get_cors_header(client, monkeypatch):
    calls = []
    monkeypatch.setattr(bridge, "square_request", fake_square(calls))
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(),
        headers={"Origin": "https://evil.example"},
    )
    assert resp.status_code == 200
    assert "Access-Control-Allow-Origin" not in resp.headers


def test_square_failure_returns_502_when_unconfigured(client, monkeypatch):
    def boom(method, path, body=None):
        raise RuntimeError("SQUARE_ACCESS_TOKEN and SQUARE_LOCATION_ID are required")

    monkeypatch.setattr(bridge, "square_request", boom)
    resp = client.post("/webhooks/formspree-pickup", json=payload())
    assert resp.status_code == 502
    assert resp.get_json()["ok"] is False


def test_open_when_app_key_unset(client, monkeypatch):
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post("/webhooks/formspree-pickup", json=payload(is_test=True))
    assert resp.status_code == 200


def test_no_origin_requires_key_when_set(client, monkeypatch):
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post("/webhooks/formspree-pickup", json=payload(is_test=True))
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "unauthorized"


def test_wrong_key_rejected(client, monkeypatch):
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(is_test=True),
        headers={"X-App-Key": "nope"},
    )
    assert resp.status_code == 401


def test_matching_key_allows_request_without_origin(client, monkeypatch):
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(is_test=True),
        headers={"X-App-Key": "shared-secret"},
    )
    assert resp.status_code == 200
    assert resp.get_json()["reference_id"].startswith("test-")


def test_allowed_origin_skips_key(client, monkeypatch):
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    for origin in (ORIGIN, OTHER_ORIGIN):
        resp = client.post(
            "/webhooks/formspree-pickup",
            json=payload(is_test=True),
            headers={"Origin": origin},
        )
        assert resp.status_code == 200, origin
        assert resp.headers["Access-Control-Allow-Origin"] == origin


def test_foreign_origin_requires_key_when_set(client, monkeypatch):
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    blocked = client.post(
        "/webhooks/formspree-pickup",
        json=payload(is_test=True),
        headers={"Origin": "https://evil.example"},
    )
    assert blocked.status_code == 401
    allowed = client.post(
        "/webhooks/formspree-pickup",
        json=payload(is_test=True),
        headers={"Origin": "https://evil.example", "X-App-Key": "shared-secret"},
    )
    assert allowed.status_code == 200


def test_options_preflight_does_not_require_key(client, monkeypatch):
    monkeypatch.setenv("APP_API_KEY", "shared-secret")
    resp = client.open("/webhooks/formspree-pickup", method="OPTIONS")
    assert resp.status_code == 204


def test_invalid_formspree_signature(client, monkeypatch):
    monkeypatch.setattr(bridge, "FORMSPREE_WEBHOOK_SECRET", "topsecret")
    monkeypatch.setattr(bridge, "square_request", forbid_square)
    resp = client.post(
        "/webhooks/formspree-pickup",
        json=payload(is_test=True),
        headers={"Origin": ORIGIN, "Formspree-Signature": "t=1,v1=deadbeef"},
    )
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "invalid signature"


def test_invalid_json(client):
    resp = client.post(
        "/webhooks/formspree-pickup",
        data="{",
        headers={"Content-Type": "application/json"},
    )
    assert resp.status_code == 400
