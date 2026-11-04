"""Password-protected /owners board for the shop.

Login is a form. A signed HttpOnly cookie keeps the session for 30 days so
the family does not have to sign in on every visit. OWNERS_PASSWORD and
OWNERS_SESSION_SECRET must both be set; otherwise the page stays closed.
"""

from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
import time
import urllib.parse
from datetime import datetime, timezone
from html import escape
from zoneinfo import ZoneInfo

from flask import Flask, make_response, redirect, request

import store

COOKIE = "owners_session"
SESSION_SECONDS = 60 * 60 * 24 * 30
LOGIN_WINDOW_SECONDS = 60
LOGIN_MAX_FAILURES = 5
NY = ZoneInfo("America/New_York")
REFERENCE_RE = re.compile(r"^[A-Za-z0-9_-]{4,80}$")

_login_failures: dict[str, list[float]] = {}


def owners_password() -> str:
    return os.environ.get("OWNERS_PASSWORD", "").strip()


def session_secret() -> str:
    return os.environ.get("OWNERS_SESSION_SECRET", "").strip()


def configured() -> bool:
    return bool(owners_password() and session_secret())


def reset_login_limits() -> None:
    _login_failures.clear()


def register(app: Flask) -> None:
    app.add_url_rule("/owners", view_func=owners_page, methods=["GET"])
    app.add_url_rule("/owners/login", view_func=owners_login, methods=["POST"])
    app.add_url_rule("/owners/logout", view_func=owners_logout, methods=["POST"])
    app.add_url_rule("/owners/<reference_id>/done", view_func=owners_mark_done, methods=["POST"])


def owners_page():
    if not configured():
        return _html(_unavailable(), status=503)
    session = _read_session()
    if not session:
        return _html(_login_page(error=""))
    rows = store.list_pickups(include_tests=True)
    return _html(_board_page(rows, session["csrf"]))


def owners_login():
    if not configured():
        return _html(_unavailable(), status=503)
    ip = request.remote_addr or "unknown"
    if _too_many_failures(ip):
        return _html(_login_page(error="Too many tries. Wait a minute and try again."), status=429)
    supplied = request.form.get("password", "")
    if hmac.compare_digest(supplied, owners_password()):
        _login_failures.pop(ip, None)
        response = redirect("/owners", code=303)
        _set_session_cookie(response)
        return response
    _note_failure(ip)
    return _html(_login_page(error="That password is not right."), status=401)


def owners_logout():
    if not configured():
        return _html(_unavailable(), status=503)
    session = _read_session()
    if not session or not _csrf_ok(session):
        return redirect("/owners", code=303)
    response = redirect("/owners", code=303)
    response.delete_cookie(COOKIE, path="/owners")
    return response


def owners_mark_done(reference_id: str):
    if not configured():
        return _html(_unavailable(), status=503)
    session = _read_session()
    if not session:
        return redirect("/owners", code=303)
    if not REFERENCE_RE.fullmatch(reference_id) or not _csrf_ok(session):
        return _html(_message("That update was rejected. Reload the page and try again."), status=400)
    done = request.form.get("done") == "1"
    store.set_done(reference_id, done)
    return redirect("/owners", code=303)


def group_pickups(rows: list[dict], now: datetime | None = None) -> dict[str, list[dict]]:
    """Split into Today, Upcoming (earlier, not done), and Done. Newest first."""
    moment = now or datetime.now(NY)
    today_date = moment.astimezone(NY).date()
    groups: dict[str, list[dict]] = {"today": [], "upcoming": [], "done": []}
    for row in rows:
        if row.get("done"):
            groups["done"].append(row)
            continue
        created = _parse_created(row.get("created_at") or "")
        if created is not None and created.astimezone(NY).date() == today_date:
            groups["today"].append(row)
        else:
            groups["upcoming"].append(row)
    return groups


def _too_many_failures(ip: str) -> bool:
    now = time.time()
    recent = [stamp for stamp in _login_failures.get(ip, []) if now - stamp < LOGIN_WINDOW_SECONDS]
    _login_failures[ip] = recent
    return len(recent) >= LOGIN_MAX_FAILURES


def _note_failure(ip: str) -> None:
    _login_failures.setdefault(ip, []).append(time.time())


def _sign(body: str) -> str:
    return hmac.new(session_secret().encode(), body.encode(), hashlib.sha256).hexdigest()


def _issue_session() -> str:
    exp = int(time.time()) + SESSION_SECONDS
    csrf = secrets.token_urlsafe(18)
    body = f"{exp}.{csrf}"
    return f"{body}.{_sign(body)}"


def _read_session() -> dict | None:
    token = request.cookies.get(COOKIE, "")
    parts = token.split(".")
    if len(parts) != 3:
        return None
    exp_raw, csrf, sig = parts
    if not csrf or not re.fullmatch(r"\d+", exp_raw):
        return None
    body = f"{exp_raw}.{csrf}"
    if not hmac.compare_digest(_sign(body), sig):
        return None
    exp = int(exp_raw)
    if exp < int(time.time()):
        return None
    return {"exp": exp, "csrf": csrf}


def _set_session_cookie(response) -> None:
    secure = request.is_secure or request.headers.get("X-Forwarded-Proto", "").split(",")[0].strip() == "https"
    response.set_cookie(
        COOKIE,
        _issue_session(),
        max_age=SESSION_SECONDS,
        httponly=True,
        samesite="Lax",
        secure=secure,
        path="/owners",
    )


def _csrf_ok(session: dict) -> bool:
    supplied = request.form.get("csrf", "")
    return bool(supplied) and hmac.compare_digest(supplied, session.get("csrf", ""))


def _html(body: str, status: int = 200):
    response = make_response(_document(body), status)
    response.headers["Content-Type"] = "text/html; charset=utf-8"
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    response.headers["Referrer-Policy"] = "no-referrer"
    return response


def _document(body: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <title>Pickups · Crystal Clean</title>
  <link rel="icon" href="/images/favicon.ico" sizes="any">
  <link rel="icon" href="/images/favicon-32.png" type="image/png" sizes="32x32">
  <link rel="apple-touch-icon" href="/images/apple-touch-icon.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,560;9..144,650&amp;family=Inter:wght@400;600;700&amp;display=swap" rel="stylesheet">
  <style>
    :root {{
      --ink: #0b2138; --muted: #5b6b7c; --brand: #2c6fae; --brand-strong: #1f5c97;
      --mist: #eaf4fb; --ice: #f5fafe; --gold: #e0a33b; --line: rgba(11, 33, 56, 0.12);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0; background: var(--ice); color: var(--ink);
      font-family: Inter, system-ui, sans-serif; line-height: 1.45;
    }}
    .wrap {{ max-width: 40rem; margin: 0 auto; padding: 1.25rem 1rem 3rem; }}
    header {{ display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: 1.25rem; }}
    h1 {{ font-family: Fraunces, Georgia, serif; font-size: 1.8rem; font-weight: 650; margin: 0; }}
    h2 {{ font-family: Fraunces, Georgia, serif; font-size: 1.25rem; margin: 1.4rem 0 0.6rem; }}
    .brand {{ display: flex; align-items: center; gap: 0.7rem; }}
    .brand img {{ width: 42px; height: 42px; border-radius: 12px; }}
    .card {{
      background: #fff; border: 1px solid var(--line); border-radius: 18px;
      padding: 1rem 1rem 0.85rem; margin: 0 0 0.75rem;
      box-shadow: 0 8px 24px rgba(11, 33, 56, 0.06);
    }}
    .card.test {{ border-color: var(--gold); }}
    .card.done {{ opacity: 0.72; }}
    .who {{ display: flex; justify-content: space-between; gap: 0.75rem; align-items: baseline; }}
    .who strong {{ font-size: 1.15rem; }}
    .when {{ color: var(--muted); font-size: 0.92rem; }}
    .badges {{ display: flex; flex-wrap: wrap; gap: 0.35rem; margin: 0.45rem 0; }}
    .badge {{
      font-size: 0.75rem; font-weight: 700; letter-spacing: 0.02em;
      background: var(--mist); color: var(--brand-strong); border-radius: 999px; padding: 0.15rem 0.55rem;
    }}
    .badge.test {{ background: #fff4df; color: #8a5a10; }}
    .tap {{
      display: block; margin-top: 0.45rem; padding: 0.8rem 0.9rem; border-radius: 12px;
      background: var(--mist); color: var(--brand-strong); text-decoration: none; font-weight: 700;
    }}
    .notes {{ margin: 0.7rem 0 0; white-space: pre-wrap; }}
    .meta {{ color: var(--muted); font-size: 0.8rem; margin-top: 0.7rem; }}
    button, .linkish {{
      font: inherit; font-weight: 700; border: 0; border-radius: 12px; min-height: 44px;
      padding: 0.65rem 0.9rem; cursor: pointer;
    }}
    button.primary, .linkish {{ background: var(--brand); color: #fff; text-decoration: none; display: inline-flex; align-items: center; }}
    button.ghost {{ background: transparent; color: var(--brand-strong); padding-left: 0; }}
    .row {{ display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap; margin-top: 0.8rem; }}
    label {{ display: block; font-weight: 600; margin-bottom: 0.35rem; }}
    input[type=password] {{
      width: 100%; font: inherit; padding: 0.8rem 0.9rem; border-radius: 12px;
      border: 1px solid var(--line); margin-bottom: 0.8rem;
    }}
    .error {{ color: #9b2c2c; font-weight: 600; }}
    .tools {{ display: flex; justify-content: space-between; gap: 0.75rem; align-items: center; }}
  </style>
</head>
<body>
  <div class="wrap">
    {body}
  </div>
</body>
</html>"""


def _login_page(error: str) -> str:
    message = f'<p class="error">{escape(error)}</p>' if error else ""
    return f"""
    <header><div class="brand"><img src="/images/icon-512.png" alt=""><h1>Pickups</h1></div></header>
    <form class="card" method="post" action="/owners/login">
      <label for="password">Shop password</label>
      {message}
      <input id="password" name="password" type="password" autocomplete="current-password" required>
      <button class="primary" type="submit">Open the list</button>
    </form>
    """


def _unavailable() -> str:
    return """
    <header><div class="brand"><h1>Pickups</h1></div></header>
    <p class="card">The owners list is not turned on yet. Set OWNERS_PASSWORD and OWNERS_SESSION_SECRET on the server.</p>
    """


def _message(text: str) -> str:
    return f'<p class="card">{escape(text)}</p>'


def _board_page(rows: list[dict], csrf: str) -> str:
    groups = group_pickups(rows)
    sections = []
    labels = (
        ("today", "Today"),
        ("upcoming", "Upcoming"),
        ("done", "Done"),
    )
    for key, label in labels:
        items = groups[key]
        if not items:
            continue
        cards = "".join(_card(row, csrf) for row in items)
        sections.append(f"<h2>{label}</h2>{cards}")
    if not sections:
        sections.append('<p class="card">No pickups yet. New website and app requests will show up here.</p>')
    logout = (
        f'<form method="post" action="/owners/logout">'
        f'<input type="hidden" name="csrf" value="{escape(csrf, quote=True)}">'
        f'<button class="ghost" type="submit">Log out</button></form>'
    )
    return f"""
    <header>
      <div class="brand"><img src="/images/icon-512.png" alt=""><h1>Pickups</h1></div>
      {logout}
    </header>
    {''.join(sections)}
    """


def _card(row: dict, csrf: str) -> str:
    classes = "card"
    if row.get("is_test"):
        classes += " test"
    if row.get("done"):
        classes += " done"
    badges = [f'<span class="badge">{"App" if row.get("source") == "app" else "Website"}</span>']
    if row.get("is_test"):
        badges.append('<span class="badge test">Test</span>')
    if row.get("done"):
        badges.append('<span class="badge">Done</span>')
    if row.get("notify_ok") is False:
        badges.append('<span class="badge test">Alert failed</span>')
    phone = row.get("phone") or ""
    tel = _tel_href(phone)
    phone_link = (
        f'<a class="tap" href="{escape(tel, quote=True)}">Call {escape(phone)}</a>'
        if tel
        else f"<p>{escape(phone)}</p>"
    )
    address = row.get("address") or ""
    line2 = row.get("address_line2") or ""
    full = ", ".join(part for part in (address, line2) if part)
    map_link = ""
    if full:
        href = "https://maps.google.com/?q=" + urllib.parse.quote(full)
        map_link = f'<a class="tap" href="{escape(href, quote=True)}">Map {escape(full)}</a>'
    notes = row.get("notes") or ""
    notes_html = f'<p class="notes">{escape(notes)}</p>' if notes else ""
    when = escape(row.get("when") or "")
    created = escape(_format_created(row.get("created_at") or ""))
    ref = escape(row.get("reference_id") or "")
    order = escape(row.get("order_id") or "")
    order_html = f" · Square {order}" if order else ""
    done_value = "0" if row.get("done") else "1"
    done_label = "Undo" if row.get("done") else "Mark done"
    action = escape(f"/owners/{row.get('reference_id')}/done", quote=True)
    return f"""
    <article class="{classes}">
      <div class="who"><strong>{escape(row.get("name") or "Pickup")}</strong><span class="when">{created}</span></div>
      <div class="badges">{''.join(badges)}</div>
      <div>When: {when}</div>
      {phone_link}
      {map_link}
      {notes_html}
      <p class="meta">{ref}{order_html}</p>
      <form method="post" action="{action}">
        <input type="hidden" name="csrf" value="{escape(csrf, quote=True)}">
        <input type="hidden" name="done" value="{done_value}">
        <div class="row"><button class="primary" type="submit">{done_label}</button></div>
      </form>
    </article>
    """


def _tel_href(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "")
    if len(digits) == 10:
        return f"tel:+1{digits}"
    if len(digits) == 11 and digits.startswith("1"):
        return f"tel:+{digits}"
    if digits:
        return f"tel:{digits}"
    return ""


def _parse_created(value: str) -> datetime | None:
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def _format_created(value: str) -> str:
    parsed = _parse_created(value)
    if parsed is None:
        return value
    local = parsed.astimezone(NY)
    clock = local.strftime("%I:%M %p").lstrip("0")
    return local.strftime("%a, %b ") + str(local.day) + " · " + clock
