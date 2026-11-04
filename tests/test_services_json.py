"""The shared catalog matches the hardcoded fallback prices on the site."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def catalog():
    return json.loads((ROOT / "data" / "services.json").read_text())


def test_pricing_page_rows_match_catalog():
    html = (ROOT / "produk.html").read_text()
    pairs = re.findall(
        r'class="name">([^<]+)</span><span class="dots"></span><span class="amt">\$([0-9]+\.[0-9]{2})</span>',
        html,
    )
    assert pairs
    items = {
        item["name"]: item
        for category in catalog()["categories"]
        for item in category["items"]
    }
    for name, amount in pairs:
        assert name in items, name
        assert f"{items[name]['price']:.2f}" == amount


def test_wash_fold_feature_price_and_note():
    html = (ROOT / "produk.html").read_text()
    assert "$1.00" in html
    assert "10 lb minimum per order" in html
    wash = next(c for c in catalog()["categories"] if c["id"] == "wash-fold")
    assert wash["layout"] == "feature"
    assert wash["from"]["label"] == "Per lb"
    assert wash["from"]["price"] == 1.0
    assert wash["from"]["unit"] == "lb"
    assert wash["items"][0]["price"] == 1.0
    assert wash["items"][0]["unit"] == "lb"
    assert wash["notes"] == "10 lb minimum per order"


def test_home_from_prices_match_catalog():
    html = (ROOT / "index.html").read_text()
    expected = {
        "dry-cleaning": ("From", "6.50"),
        "wash-fold": ("Per lb", "1.00"),
        "laundered-shirts": ("From", "2.00"),
        "tailoring": ("From", "15.00"),
    }
    by_id = {c["id"]: c for c in catalog()["categories"]}
    assert set(expected) == set(by_id)
    for cat_id, (label, amount) in expected.items():
        assert f'data-service="{cat_id}"' in html
        assert by_id[cat_id]["from"]["label"] == label
        assert f"{by_id[cat_id]['from']['price']:.2f}" == amount
        # Fallback HTML still shows the same From price before JS runs.
        card = html.split(f'data-service="{cat_id}"', 1)[1].split("</article>", 1)[0]
        assert f'<span class="from">{label}</span>' in card
        assert f'<span class="price">${amount}</span>' in card


def test_pages_load_the_catalog_script():
    for name in ("index.html", "produk.html"):
        html = (ROOT / name).read_text()
        assert 'src="services.js?v=1"' in html
    nginx = (ROOT / "nginx.conf").read_text()
    assert "location = /data/services.json" in nginx
    assert "application/json" in nginx
    assert "max-age=300" in nginx


def test_customer_form_does_not_send_a_test_flag():
    html = (ROOT / "request-pickup.html").read_text()
    assert "is_test" not in html
    assert "X-Test" not in html
    assert "X-App-Key" not in html


def test_nginx_limits_the_webhook_and_echoes_only_site_origins():
    nginx = (ROOT / "nginx.conf").read_text()
    assert "limit_req_zone $binary_remote_addr zone=pickup_webhook:10m rate=10r/m;" in nginx
    assert "limit_req zone=pickup_webhook burst=5 nodelay;" in nginx
    assert "https://crystalcleandrycleaner.com" in nginx
    assert "https://www.crystalcleandrycleaner.com" in nginx
    assert "$http_origin always" not in nginx
    assert "proxy_set_header X-App-Key $http_x_app_key;" in nginx
    assert "proxy_set_header X-Test $http_x_test;" in nginx
    assert "limit_req_zone $binary_remote_addr zone=owners_login:10m rate=5r/m;" in nginx
    assert "location = /owners/login" in nginx
    assert "limit_req zone=owners_login burst=3 nodelay;" in nginx
    assert "location /owners" in nginx
    assert 'X-Robots-Tag "noindex, nofollow"' in nginx
    assert 'Cache-Control "no-store"' in nginx
