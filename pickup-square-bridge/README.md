# Pickup → Square bridge

Small Flask service that turns Formspree pickup submissions into **$0 paid Square PICKUP orders** so your store printer can print order tickets.

## Flow

1. Customer submits [`request-pickup.html`](../request-pickup.html)
2. The website still posts the form to Formspree (email + Discord) and the same fields as JSON to this bridge
3. The iOS app posts only to this bridge. It does not call Formspree itself
4. Bridge creates a Square order (`Pickup Request`, $0) with ASAP pickup fulfillment. Website orders use `web-pickup-<12 hex>`. App orders (`X-App-Key` and no site Origin) use `app-pickup-<12 hex>`. Test orders stay `test-<12 hex>`
5. For app callers only, the bridge then forwards the same seven fields to Formspree. Website posts are not forwarded, so the shop does not get two emails
6. Bridge calls `PayOrder` (required — unpaid orders never reach POS/printers)
7. Square prints the ticket if printer profiles allow online order tickets

## Run with the site

From the project root:

```bash
# Fill in pickup-square-bridge/.env (see .env.example)
docker compose up -d --build
```

Endpoints:

| URL | Purpose |
|-----|---------|
| `http://HOST:3015/health` | Health check |
| `http://HOST:3015/webhooks/formspree-pickup` | Direct webhook |
| `https://YOUR_DOMAIN/webhooks/formspree-pickup` | Same path via site nginx proxy |

## Formspree setup

No paid Webhook plugin needed. The website still dual-submits:

1. Formspree (free) → email notification  
2. `POST /webhooks/formspree-pickup` → Square order / print ticket  

The iOS app posts only to the bridge. When that request has `X-App-Key` and its Origin is not one of the two site hosts, the bridge forwards the submission to Formspree itself (`FORMSPREE_FORM_URL`, default `https://formspree.io/f/mjgewqpz`). The body uses the same field names and order as the website form (`name`, `phone`, `email`, `address`, `address_line2`, `when`, `notes`), with `Accept: application/json` and both `Origin` and `Referer` set to `https://www.crystalcleandrycleaner.com/request-pickup.html`. A test request also sends `_subject` `[TEST] Pickup request — please ignore` and prefixes the name with `[TEST] ` when it is not already prefixed. The bridge does not pretend to be a browser.

Formspree’s Formshield may still flag a server-side post. The JSON response reports `square_ok` and `notify_ok` separately. `ok` stays true when the ticket was created, even if the alert failed. The owners list shows **Alert failed** on those rows. A website post leaves `notify_ok` null, because the page already sent the email.

If you later enable Formspree’s Webhook plugin anyway, point it at the same URL; the bridge accepts both browser and Formspree payloads.

## Test requests (no Square order)

Send `is_test: true` in the JSON body, or the header `X-Test: 1` (also accepts `true` / `yes`). The bridge does **not** call Square. It still saves the request for the owners page and labels it as a test. Response:

```json
{"ok": true, "test": true, "square_ok": true, "notify_ok": null, "reference_id": "test-…"}
```

`notify_ok` is `true` or `false` for an app caller, and `null` for the website. The public form does not send this flag. Real customers still create a normal order.

An app test still asks the bridge to forward a labeled Formspree alert. The bridge sets `_subject` to `[TEST] Pickup request — please ignore` and prefixes the name with `[TEST] `.

```bash
curl -s http://127.0.0.1:3015/webhooks/formspree-pickup \
  -H 'Content-Type: application/json' \
  -H 'X-Test: 1' \
  -H "X-App-Key: $APP_API_KEY" \
  -d '{"is_test":true,"name":"Test Customer","phone":"6465551234","email":"test@example.com","address":"400 E 87th Street, New York, NY 10128","address_line2":"","when":"Tomorrow 10am","notes":"ignore"}'
```

`test_local.py` sends a test request unless `BRIDGE_LIVE=1`.

## Abuse protection

`APP_API_KEY` is optional.

- Unset: anyone can post, same as before.
- Set: a request whose `Origin` is `https://crystalcleandrycleaner.com` or `https://www.crystalcleandrycleaner.com` still works **without** the key (the website). Any other request, including one with **no** `Origin` (the iOS app, curl, a Formspree webhook), must send `X-App-Key` equal to `APP_API_KEY`.

Nginx rate-limits `POST /webhooks/formspree-pickup` to **10 requests/minute per IP**, with a burst of 5 (so the browser preflight plus a retry still go through). Extra requests get `429`. The preflight echoes `Access-Control-Allow-Origin` only for those two hosts.

## Owners list

Open `https://YOUR_DOMAIN/owners` on a phone. Set `OWNERS_PASSWORD` and `OWNERS_SESSION_SECRET` in `.env` and restart the bridge. Until both are set, the page stays closed.

The list updates itself. Website requests are labeled Website and use a `web-pickup-` reference. Requests that arrive with `X-App-Key` and no site Origin (the iOS app) are labeled App and use an `app-pickup-` reference. Newest first, grouped into **Today**, **Upcoming** (still open from earlier days), and **Done**, in US Eastern time. Phone numbers call, addresses open a map. Test requests stay in that same list with a small **Test** badge. A failed shop alert shows **Alert failed**. **Mark done** is optional and only changes this list. The login cookie lasts 30 days.

Nginx allows 5 login attempts per minute per IP (burst 3). The page sends `noindex` and `Cache-Control: no-store`.

Requests are stored in SQLite at `SQLITE_PATH` (Compose uses a volume at `/data/pickups.db`).

## Local sandbox test

```bash
docker compose up -d --build pickup-bridge
python3 pickup-square-bridge/test_local.py          # is_test, no Square order
BRIDGE_LIVE=1 python3 pickup-square-bridge/test_local.py   # real Square order
```

Unit tests mock Square and do not touch the network:

```bash
pip install -r pickup-square-bridge/requirements-dev.txt
pytest pickup-square-bridge/tests tests
```

A live sandbox order will **not** print on the physical store printer. Production needs `SQUARE_ENV=production`, a production access token, and the real store `SQUARE_LOCATION_ID`.

## Square POS printer checklist (production)

On the store device: Settings → Printers → profile → enable **Online and kiosk order tickets** / **Automatically Print New Orders**.
