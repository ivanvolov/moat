# Moat Landing Page

Static landing site for Moat. Plain HTML + CSS — no build step, no dependencies.

## Run locally

Any static file server works. Pick one:

```shell
# Python
python3 -m http.server 8000

# Node
npx serve .
```

Then open `http://localhost:8000`.

## Deploy to GitHub Pages

The site is deployed via [`.github/workflows/deploy-pages.yml`](../.github/workflows/deploy-pages.yml), which uploads the contents of `app/` on every push to `main`.

To enable deployment:

1. Open the repository **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **GitHub Actions**.
3. Merge the workflow to `main`.

Subsequent pushes to `main` that touch `app/` will redeploy the project site (typically `https://ivanvolov.github.io/moat/`).

## Contents

- `index.html` — landing page markup
- `styles.css` — styling
- `assets/` — images and static media
