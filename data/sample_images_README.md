# Sample images

By default the SQL uses **Base64 data URLs** inline, so the demo runs with **zero
network image fetches**. `FETCH_CONTENT(data:...)` hands a data URL straight to
the embedding model. If you would rather use **public HTTPS images**, point
`image_url` (in `events.json` / the SQL `VALUES`) at any public image that
matches the event's subject, e.g. from a CDN or OSS public bucket:

| event | suggested public subject | example source |
|-------|--------------------------|----------------|
| e1 | outdoor/hiking jacket photo | any CC0 outdoor-clothing image |
| e2 | smart wearable bracelet      | any CC0 smart-watch/band image |
| e3 | plain face-cream jar         | any CC0 cosmetics image |

## Generating byte-exact local PNG fixtures (optional)

`scripts/generate_sample_images.py` paints three simple PNGs (one per event) so
you have reproducible local image fixtures. It prints the data URL for each; use
the output to replace the `PLACEHOLDER_Ex` tokens in `events.json` if you want
the demo's staged data to reference real differing images:

```bash
python3 scripts/generate_sample_images.py   # writes data/images/*.png + prints data URLs
```

No model accepts an all-black 1×1 PNG meaningfully, so **for real inference,
either use a public image URL (table above) or generate the fixtures and point
`image_url` at a working endpoint** — the inline `PLACEHOLDER` data URLs in the
SQL are only there to keep the query grammatically complete and graph-building
successful without external I/O.