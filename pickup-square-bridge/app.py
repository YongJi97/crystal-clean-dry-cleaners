"""Formspree → Square bridge for Crystal Clean pickup requests.

Receives Formspree webhooks and browser JSON posts, then creates a $0 paid
PICKUP order so Square can surface the ticket on POS / print order tickets.

Test clients send is_test: true and/or X-Test: 1. Those requests do not create
a Square order; the response is {ok, test, reference_id} and nothing is stored.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import os
import re
import time
import uuid
from typing import Any

import requests
from flask import Flask, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("pickup-bridge")

SQUARE_ACCESS_TOKEN = os.environ.get("SQUARE_ACCESS_TOKEN", "").strip()
SQUARE_LOCATION_ID = os.environ.get("SQUARE_LOCATION_ID", "").strip()
SQUARE_ENV = os.environ.get("SQUARE_ENV", "sandbox").strip().lower()
SQUARE_PICKUP_VARIATION_ID = os.environ.get("SQUARE_PICKUP_VARIATION_ID", "").strip()
FORMSPREE_WEBHOOK_SECRET = os.environ.get("FORMSPREE_WEBHOOK_SECRET", "").strip()
SQUARE_VERSION = os.environ.get("SQUARE_VERSION", "2025-01-16").strip()
WEBHOOK_TOLERANCE_SECONDS = int(os.environ.get("WEBHOOK_TOLERANCE_SECONDS", "300"))

SQUARE_BASE = (
    "https://connect.squareup.com/v2"
    if SQUARE_ENV == "production"
    else "https://connect.squareupsandbox.com/v2"
)

# Browser dual-submit from the public site (no Formspree webhook needed)
ALLOWED_ORIGINS = {
    o.strip()
    for o in os.environ.get(
        "ALLOWED_ORIGINS",
        "https://crystalcleandrycleaner.com,https://www.crystalcleandrycleaner.com",
    ).split(",")
    if o.strip()
}

_TRUE_STRINGS = {"1", "true", "yes"}


def app_api_key() -> str:
    """Shared secret for non-browser clients. Empty means the check is off."""
    return os.environ.get("APP_API_KEY", "").strip()


def square_request(method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    if not SQUARE_ACCESS_TOKEN or not SQUARE_LOCATION_ID:
        raise RuntimeError("SQUARE_ACCESS_TOKEN and SQUARE_LOCATION_ID are required")

    url = f"{SQUARE_BASE}{path}"
    headers = {
        "Authorization": f"Bearer {SQUARE_ACCESS_TOKEN}",
        "Square-Version": SQUARE_VERSION,
        "Content-Type": "application/json",
    }
    resp = requests.request(method, url, headers=headers, json=body, timeout=30)
    try:
        payload = resp.json()
    except ValueError:
        payload = {"raw": resp.text}

    if not resp.ok:
        log.error("Square %s %s failed (%s): %s", method, path, resp.status_code, payload)
        raise RuntimeError(f"Square API error {resp.status_code}: {payload}")
    return payload


def normalize_phone(raw: str) -> str | None:
    digits = re.sub(r"\D", "", raw or "")
    if len(digits) == 10:
        return f"+1{digits}"
    if len(digits) == 11 and digits.startswith("1"):
        return f"+{digits}"
    if raw and raw.strip().startswith("+") and len(digits) >= 10:
        return f"+{digits}"
    return None


def verify_formspree_signature(secret: str, header: str, raw_body: bytes) -> bool:
    """Verify Formspree-Signature: t=<unix>,v1=<hex> over f'{t}.{raw_body}'."""
    if not secret:
        return True
    if not header:
        return False

    parts = dict(p.split("=", 1) for p in header.split(",") if "=" in p)
    ts = parts.get("t")
    sig = parts.get("v1")
    if not ts or not sig:
        return False

    try:
        ts_int = int(ts)
    except ValueError:
        return False

    if abs(time.time() - ts_int) > WEBHOOK_TOLERANCE_SECONDS:
        log.warning("Webhook timestamp outside tolerance: %s", ts)
        return False

    signed = f"{ts}.".encode() + raw_body
    expected = hmac.new(secret.encode(), signed, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sig)


def extract_submission(payload: dict[str, Any]) -> dict[str, Any]:
    """Support Formspree webhook envelope and flat/test payloads."""
    if isinstance(payload.get("submission"), dict):
        return payload["submission"]
    # Flat body (manual tests / Zapier-style)
    return payload


def flag_is_true(value: Any) -> bool:
    if value is True or value == 1:
        return True
    if isinstance(value, str) and value.strip().lower() in _TRUE_STRINGS:
        return True
    return False


def request_is_test(payload: dict[str, Any], data: dict[str, Any]) -> bool:
    """True when the body says is_test or the client sent X-Test: 1."""
    if flag_is_true(data.get("is_test")) or flag_is_true(payload.get("is_test")):
        return True
    header = (request.headers.get("X-Test") or "").strip().lower()
    return header in _TRUE_STRINGS


def request_authorized() -> bool:
    """Browser calls from the site origins stay open.

    When APP_API_KEY is set, every other caller (no Origin, or an Origin that
    is not on the allowlist) must send X-App-Key. When the env var is unset,
    behavior matches the previous open webhook.
    """
    key = app_api_key()
    if not key:
        return True
    origin = (request.headers.get("Origin") or "").strip()
    if origin in ALLOWED_ORIGINS:
        return True
    provided = request.headers.get("X-App-Key") or ""
    return hmac.compare_digest(provided, key)


def build_ticket_note(data: dict[str, Any]) -> str:
    address = (data.get("address") or "").strip()
    line2 = (data.get("address_line2") or "").strip()
    if line2:
        address = f"{address}, {line2}" if address else line2

    lines = [
        "WEB PICKUP REQUEST",
        f"Name: {(data.get('name') or '').strip()}",
        f"Phone: {(data.get('phone') or '').strip()}",
        f"Email: {(data.get('email') or '').strip() or '—'}",
        f"Address: {address or '—'}",
        f"When: {(data.get('when') or '').strip() or '—'}",
        f"Notes: {(data.get('notes') or '').strip() or '—'}",
    ]
    return "\n".join(lines)


def create_pickup_order(data: dict[str, Any]) -> dict[str, Any]:
    name = (data.get("name") or "Pickup customer").strip() or "Pickup customer"
    phone = normalize_phone(data.get("phone") or "")
    email = (data.get("email") or "").strip() or None
    note = build_ticket_note(data)

    recipient: dict[str, Any] = {"display_name": name}
    if phone:
        recipient["phone_number"] = phone
    if email:
        recipient["email_address"] = email

    if SQUARE_PICKUP_VARIATION_ID:
        line_item: dict[str, Any] = {
            "catalog_object_id": SQUARE_PICKUP_VARIATION_ID,
            "quantity": "1",
            "note": note[:2000],
        }
    else:
        line_item = {
            "name": "Pickup Request",
            "quantity": "1",
            "base_price_money": {"amount": 0, "currency": "USD"},
            "note": note[:2000],
        }

    order_body = {
        "idempotency_key": str(uuid.uuid4()),
        "order": {
            "location_id": SQUARE_LOCATION_ID,
            "reference_id": f"web-pickup-{uuid.uuid4().hex[:12]}",
            "line_items": [line_item],
            "fulfillments": [
                {
                    "type": "PICKUP",
                    "state": "PROPOSED",
                    "pickup_details": {
                        "schedule_type": "ASAP",
                        "recipient": recipient,
                        "note": note[:500],
                    },
                }
            ],
        },
    }

    created = square_request("POST", "/orders", order_body)
    order = created.get("order") or {}
    order_id = order.get("id")
    if not order_id:
        raise RuntimeError(f"CreateOrder missing order id: {created}")

    # $0 orders can be completed via PayOrder with no payment IDs.
    paid = square_request(
        "POST",
        f"/orders/{order_id}/pay",
        {"idempotency_key": str(uuid.uuid4())},
    )
    return {
        "order_id": order_id,
        "order_state": (paid.get("order") or order).get("state"),
        "reference_id": order.get("reference_id"),
    }


@app.after_request
def add_cors_headers(response):
    origin = (request.headers.get("Origin") or "").strip()
    if origin and origin in ALLOWED_ORIGINS:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, X-App-Key, X-Test"
        response.headers["Vary"] = "Origin"
    return response


@app.get("/health")
def health():
    return jsonify(
        {
            "ok": True,
            "square_env": SQUARE_ENV,
            "location_configured": bool(SQUARE_LOCATION_ID),
            "token_configured": bool(SQUARE_ACCESS_TOKEN),
            "catalog_item_configured": bool(SQUARE_PICKUP_VARIATION_ID),
            "app_key_configured": bool(app_api_key()),
        }
    )


@app.route("/webhooks/formspree-pickup", methods=["OPTIONS"])
@app.route("/webhook", methods=["OPTIONS"])
def cors_preflight():
    return ("", 204)


@app.post("/webhooks/formspree-pickup")
@app.post("/webhook")
def formspree_pickup():
    if not request_authorized():
        log.warning("Rejected pickup: missing or invalid X-App-Key")
        return jsonify({"ok": False, "error": "unauthorized"}), 401

    raw = request.get_data()
    sig_header = request.headers.get("Formspree-Signature", "")

    if FORMSPREE_WEBHOOK_SECRET and not verify_formspree_signature(
        FORMSPREE_WEBHOOK_SECRET, sig_header, raw
    ):
        log.warning("Rejected webhook: invalid Formspree signature")
        return jsonify({"ok": False, "error": "invalid signature"}), 401

    try:
        payload = request.get_json(force=True, silent=False) or {}
    except Exception:
        return jsonify({"ok": False, "error": "invalid JSON"}), 400

    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "invalid JSON"}), 400

    data = extract_submission(payload)
    if not isinstance(data, dict):
        return jsonify({"ok": False, "error": "invalid JSON"}), 400

    name = (data.get("name") or "").strip()
    phone = (data.get("phone") or "").strip()
    address = (data.get("address") or "").strip()
    when = (data.get("when") or "").strip()

    if not (name and phone and address and when):
        log.warning("Rejected webhook: missing required fields %s", list(data.keys()))
        return jsonify({"ok": False, "error": "missing required fields"}), 400

    if request_is_test(payload, data):
        reference_id = f"test-{uuid.uuid4().hex[:12]}"
        log.info("Accepted test pickup ref=%s for %s (no Square order)", reference_id, name)
        return jsonify({"ok": True, "test": True, "reference_id": reference_id}), 200

    try:
        result = create_pickup_order(data)
    except Exception as exc:
        log.exception("Failed to create Square order")
        # Still 200 so Formspree does not hammer retries forever for bad data;
        # return 502 for transient/config failures so they can retry.
        status = 502 if "Square API error 5" in str(exc) or "required" in str(exc).lower() else 500
        return jsonify({"ok": False, "error": str(exc)}), status

    log.info(
        "Created Square pickup order %s ref=%s for %s",
        result["order_id"],
        result.get("reference_id"),
        name,
    )
    return jsonify({"ok": True, **result}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
