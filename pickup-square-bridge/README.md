# Pickup → Square bridge

Small Flask service that turns Formspree pickup submissions into **$0 paid Square PICKUP orders** so your store printer can print order tickets.

## Flow

1. Customer submits [`request-pickup.html`](../request-pickup.html) → Formspree
2. Formspree Webhook plugin POSTs JSON here
3. Bridge creates a Square order (`Pickup Request`, $0) with ASAP pickup fulfillment
4. Bridge calls `PayOrder` (required — unpaid orders never reach POS/printers)
5. Square prints the ticket if printer profiles allow online order tickets

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

No paid Webhook plugin needed. The site dual-submits:

1. Formspree (free) → email notification  
2. `POST /webhooks/formspree-pickup` → Square order / print ticket  

If you later enable Formspree’s Webhook plugin anyway, point it at the same URL; the bridge accepts both browser and Formspree payloads.

## Local sandbox test

```bash
docker compose up -d --build pickup-bridge
python3 pickup-square-bridge/test_local.py
```

Sandbox creates real API orders but will **not** print on the physical store printer. Production needs `SQUARE_ENV=production`, a production access token, and the real store `SQUARE_LOCATION_ID`.

## Square POS printer checklist (production)

On the store device: Settings → Printers → profile → enable **Online and kiosk order tickets** / **Automatically Print New Orders**.
