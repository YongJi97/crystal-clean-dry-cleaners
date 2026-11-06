"""The public site links the published iPhone app and keeps website pickup."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGES = ["index.html", "menu.html", "privacy.html", "produk.html", "request-pickup.html"]
APP_STORE = "https://apps.apple.com/us/app/crystal-clean-dry-cleaners/id6830972978"


def test_every_page_links_the_iphone_app_and_not_android():
    for name in PAGES:
        text = (ROOT / name).read_text()
        assert text.count(APP_STORE) >= 1, name
        assert 'name="apple-itunes-app" content="app-id=6830972978"' in text, name
        lowered = text.lower()
        assert "android" not in lowered, name
        assert "google play" not in lowered, name
        assert "request-pickup.html" in text, name


def test_homepage_keeps_website_pickup_beside_the_app_store_badge():
    text = (ROOT / "index.html").read_text()
    hero = text.split('<section class="app-download"', 1)[0]
    assert 'class="btn btn-primary btn-lg"' in hero
    assert 'href="request-pickup.html"' in hero
    band = text.split('<section class="app-download"', 1)[1].split("</section>", 1)[0]
    assert band.count(APP_STORE) == 1
    assert "See prices, save your details, and send pickup requests." in band
    assert 'href="request-pickup.html"' in band
    assert "Or request a pickup on this website" in band
    assert 'aria-label="Download Crystal Clean Dry Cleaners on the App Store"' in band
