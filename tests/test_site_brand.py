"""The public pages use the square crystal icon, not the old round badge."""

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGES = ["index.html", "menu.html", "privacy.html", "produk.html", "request-pickup.html"]
ICON_LINKS = [
    'rel="icon" href="./images/favicon.ico"',
    'rel="icon" href="./images/favicon-32.png"',
    'rel="apple-touch-icon" href="./images/apple-touch-icon.png"',
    'rel="manifest" href="./site.webmanifest"',
    "images/icon-512.png",
    "Crystal Clean<span class=\"brand-sub\">Dry Cleaners</span>",
]


def test_every_page_links_the_new_icon_and_wordmark():
    for name in PAGES:
        text = (ROOT / name).read_text()
        for snippet in ICON_LINKS:
            assert snippet in text, f"{name} missing {snippet}"
        assert "cleaner_logo.png" not in text
        assert "favicon-32x32.png" not in text
    assert not (ROOT / "images/cleaner_logo.png").exists()
    assert not (ROOT / "images/favicon-32x32.png").exists()


def _png_size_and_color(path: Path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return width, height, color_type


def test_generated_icons_are_opaque_at_the_expected_sizes():
    expected = {
        "images/favicon-32.png": (32, 32),
        "images/apple-touch-icon.png": (180, 180),
        "images/icon-512.png": (512, 512),
        "ios/CrystalClean/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png": (1024, 1024),
        "ios/CrystalClean/Resources/Assets.xcassets/Logo.imageset/logo.png": (512, 512),
    }
    for relative, size in expected.items():
        width, height, color_type = _png_size_and_color(ROOT / relative)
        assert (width, height) == size
        assert color_type == 2  # RGB, no alpha
    ico = (ROOT / "images/favicon.ico").read_bytes()
    assert ico[:4] == b"\x00\x00\x01\x00"
    count = struct.unpack("<H", ico[4:6])[0]
    assert count == 3


def test_manifest_points_at_the_generated_icons():
    text = (ROOT / "site.webmanifest").read_text()
    assert "Crystal Clean Dry Cleaners" in text
    assert "/images/favicon-32.png" in text
    assert "/images/apple-touch-icon.png" in text
    assert "/images/icon-512.png" in text
