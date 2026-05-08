# Crystal Clean Dry Cleaners

Marketing website for **Crystal Clean Dry Cleaners**, a neighborhood dry cleaning, wash & fold, and tailoring shop on the Upper East Side of Manhattan.

- **Address:** 400 E 87th Street, New York, NY 10128
- **Phone:** [646-338-6883](tel:6463386883)
- **Hours:** Mon–Sat, 7:30 AM – 7:00 PM

## Stack

A static site — no build step required.

- Plain HTML5 + CSS3 + vanilla JS
- [Bootstrap 5.3.2](https://getbootstrap.com/) (via CDN)
- [Font Awesome 6.4.0](https://fontawesome.com/) free icons (via CDN)
- [Formspree](https://formspree.io/) for the pickup-request form
- [PlaceKit](https://placekit.io/) for address autocomplete
- Google Analytics (`G-HDLGS3C2DZ`)

## Pages

| File | Path served by nginx | Purpose |
| --- | --- | --- |
| `index.html` | `/` | Home / hero / how it works / map |
| `produk.html` | `/pricing` | Pricing & services + FAQ |
| `menu.html` | `/menu` | Paper menu / flyer images |
| `request-pickup.html` | `/request-pickup.html` | Pickup request form (Formspree) |

URL rewrites are configured in `nginx.conf` so the `.html` extensions don't show up in the address bar.

## Local development

The site is fully static — open `index.html` directly in a browser, or serve the folder with any static server:

```bash
# Python 3
python -m http.server 8080

# Node
npx serve .
```

Then visit <http://localhost:8080>.

> **Note:** when opening the files directly (`file://`) or serving without nginx, `/pricing` and `/menu` rewrites are not available. Internal links use the actual `.html` filenames so the site still works.

## Deployment

The site ships as a Docker container running nginx.

```bash
docker compose up --build -d
```

This builds the image from the `Dockerfile` (which copies the static files into `/usr/share/nginx/html`) and serves the site on port 80 with the rewrite rules in `nginx.conf`.

## Configuration to update before going live

A few values in the source still use placeholder defaults — search the repo for these and replace as needed:

- **Domain** — `https://crystalcleandrycleaners.com/` is used in `<link rel="canonical">`, Open Graph tags, the JSON-LD schema in `index.html`, `robots.txt`, and `sitemap.xml`. Update to the real domain when finalized.
- **Social links** — the footer Facebook / Instagram / Twitter / TikTok icons in all three main pages still link to `href="#"`. Look for the `<!-- TODO: replace href="#" with real social profile URLs -->` markers.
- **Formspree form ID** — set in `request-pickup.html` (`FORMSPREE_FORM_ID`).
- **PlaceKit API key** — set in `request-pickup.html` (`PLACEKIT_API_KEY`). Free tier is 10,000 requests/month.

## SEO

- Per-page `<title>` and `<meta name="description">`
- Open Graph + Twitter Card tags
- `LocalBusiness` (`DryCleaningOrLaundry`) JSON-LD on the home page (address, phone, hours, geo)
- `robots.txt` + `sitemap.xml`
- Canonical URLs on every page

## License

[MIT](LICENSE)
