# Street View AC Inspector

Detect and map external wall-mounted air-conditioning units across a city
using Google Street View imagery and a vision model. Built as a POC focused
on Accra, Ghana, but the geometry assumes nothing about location — only
that Street View coverage exists.

The app gives you two operating modes:

- **Manual** — navigate the Street View panorama, click *Capture & Analyze*
  on whatever you're pointing at, save individual frames to a local SQLite DB.
- **Explore** — pick an area (a center+radius or a 4-corner bounding box),
  hit *Start Explore*, and let a BFS pano walker visit every Street View
  stop in that area, capture 4 frames per stop (north / east / south / west),
  send each to the chosen detector, and auto-save the verdicts.

Two interchangeable detectors are wired in:

- **Claude Sonnet 4.6 vision** (default) — sends each frame to the Anthropic
  API with a structured JSON-output prompt. Returns `has_ac`, `count`,
  `confidence`, `reasoning`, and per-call token usage.
- **SAM 3** — Meta's open-vocabulary segmentation model, run via a local
  FastAPI wrapper on Apple Silicon (MPS) or via Modal Labs for scale-out.
  Same wire contract as Claude, so the rest of the pipeline doesn't care
  which one ran.

---

## Architecture at a glance

```
┌─────────────────┐  HTTP  ┌──────────────────────┐  HTTP  ┌────────────────┐
│  Browser        │───────▶│  Node / Express      │───────▶│  Anthropic API │
│  (Maps JS,      │        │  server.js           │        └────────────────┘
│   Street View   │◀───────│  detectors.js        │  HTTP  ┌────────────────┐
│   panorama)     │        │  db.js (sqlite)      │───────▶│  SAM 3 wrapper │
└─────────────────┘        └──────────────────────┘        │  (local/Modal) │
        │                          │                       └────────────────┘
        │ Maps JS API              │ Static API
        ▼                          ▼
   maps.googleapis.com   maps.googleapis.com/streetview
```

- **Browser** runs the Google Maps JS panorama for navigation, owns the
  pano-graph BFS in explore mode, and renders the live UI.
- **Server** is a small Express app: serves the static frontend, fetches
  Street View Static images server-side (so your API key isn't sent
  through the browser), proxies analysis requests to whichever detector
  the user picked, and persists results to a single-file SQLite DB.
- **SAM 3 wrapper** is optional. When unset, `SAM3_ENDPOINT_URL` defaults
  to `http://127.0.0.1:8765/predict`, which is what `inference/sam3_local.py`
  exposes when you run it.

---

## How the detection works

Both modes share the same per-frame pipeline:

1. **Fetch a frame** from the Street View Static API at a chosen
   `(lat, lng, heading, pitch, fov)`. Server-side, so the API key stays
   off the wire.
2. **Skip placeholders.** Google returns a ~8.8 KB grey "Sorry, we have
   no imagery here" placeholder when a pano exists nearby but the
   requested view has no rendered tiles. We short-circuit on
   `imageBuf.length < 15 KB` and return a low-confidence skipped verdict
   without spending a detector call.
3. **Send to the detector** of choice. Both return the same shape:

   ```json
   {
     "has_ac":     true,
     "count":      3,
     "confidence": "high",
     "reasoning":  "Three white wall-mounted condenser units...",
     "usage":      { "input_tokens": 727, "output_tokens": 64 }
   }
   ```

4. **Persist** the row with `pano_id`, view params, the saved JPEG path,
   and (in explore mode) a `batch_id`.

### Manual mode

Navigate the panorama with the mouse. The bottom bar shows live
`coords`, `heading`, `pitch`. Click **Capture & Analyze** → the server
fetches the frame, runs the detector, returns the image URL + verdict.
Click **Save to DB** to persist with the live `pano_id`.

### Explore mode (BFS pano walker)

Driven by a `bounds` object with three required fields:

```js
{
  seed:     { lat, lng },                // BFS seed point
  contains: (lat, lng) => boolean,        // membership predicate
  label:    string                        // "200m radius" / "4-corner area"
}
```

For **radius mode**, `contains` is a haversine check. For **bbox mode**,
the four corners build a `google.maps.Polygon` (path order TL → TR → BR → BL)
and containment is delegated to `google.maps.geometry.poly.containsLocation`,
so tilted quadrilaterals work correctly without rolling our own
point-in-polygon.

The walker:

1. Allocates a `batch_id` from `POST /api/batch/start` (`COALESCE(MAX, 0) + 1`).
2. Seeds the queue with the nearest pano to the seed point
   (centroid of the four corners in bbox mode).
3. While the queue is non-empty and the pano cap isn't hit:
   - Pop a pano. Skip if outside `bounds.contains`.
   - Move the visible panorama to it (so the user watches the walk).
   - For each of 4 headings (0° / 90° / 180° / 270°), call
     `/api/analyze` then `/api/save` with the batch id.
   - Stream the result into the live log + token counter.
   - Enqueue every link neighbor (`pano.links`) that's also inside `bounds`
     and not yet visited.
4. On completion, refresh the saved-detections list and the
   *Exploration batches* panel.

The 4-heading sweep aligns with the documented `p_id` convention in the
CSV export — `<pano_id>_<deg>` where deg ∈ {0, 90, 180, 270}.

---

## Setup

### Prerequisites

- **Node.js ≥ 22** — uses the built-in `node:sqlite` module and
  `node --watch`. Tested on 25.5.
- **Google Maps Platform API key** with these APIs enabled:
  - Maps JavaScript API
  - Street View Static API
  - Geocoding API (for the address jump and bbox corner lookups)
- **Anthropic API key** for the Claude detector path.
- **(Optional, SAM 3)** Hugging Face account with access granted to
  [`facebook/sam3`](https://huggingface.co/facebook/sam3),
  Python 3.12, and either an MPS-capable Mac or a CUDA box for the
  local wrapper — or a Modal account for the hosted recipe.

### Environment variables (`.env.local`)

```
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIza...        # browser-exposed; restrict by HTTP referrer
GOOGLE_MAPS_SERVER_KEY=                         # optional; falls back to NEXT_PUBLIC_ if empty
ANTHROPIC_API_KEY=sk-ant-...

# Optional — SAM 3
SAM3_ENDPOINT_URL=                              # defaults to http://127.0.0.1:8765/predict
SAM3_AUTH_TOKEN=                                # only if your endpoint requires auth
SAM3_PROMPT=                                    # override the default text prompt

# Optional — server config
PORT=3100
POC_DB_PATH=                                    # override the default poc.db (used for tests)
```

### Install + first run

```bash
npm install
npm run dev          # starts on http://localhost:3100, hot-reloads on file changes
```

The `dev` script uses `node --watch` so changes to `server.js`,
`db.js`, or `detectors.js` reload automatically. Frontend changes
(`public/*`) are served as static files — refresh the browser.

---

## Running with Claude (default)

Once `.env.local` is filled in:

```bash
npm install
npm run dev
```

Open `http://localhost:3100`, leave **Detector** on *Claude*, and use
either manual capture or explore mode. Saved rows are tagged with a
blue `claude` badge.

**Cost expectation per frame:** ~$0.007 Google Static API + ~$0.008
Claude vision = **~$0.015 / frame**. A 40-pano explore at 4 headings/pano
is ~$2.40 total.

---

## Running with SAM 3 (local)

SAM 3 is open-weights only on
[`github.com/facebookresearch/sam3`](https://github.com/facebookresearch/sam3) —
no hosted public API exists. The local wrapper runs the model on your
own hardware (MPS on Apple Silicon, or CUDA elsewhere) and exposes the
same JSON contract `detectors.js` already speaks.

### One-time setup

```bash
# 1. Request access to the checkpoints (one-time, takes minutes to hours
#    for Meta to approve — must be done before the wrapper can download
#    weights). Visit https://huggingface.co/facebook/sam3 and click
#    "Request access".

# 2. Install Python deps into inference/.venv (~5–10 minutes).
npm run sam3:setup

# 3. Authenticate the Hugging Face CLI so the model can be downloaded.
source inference/.venv/bin/activate
hf auth login                                   # paste your HF read token
```

### Each session

Two terminals:

```bash
# Terminal A — Node server
npm run dev

# Terminal B — SAM 3 wrapper (first call downloads ~3 GB of weights)
npm run sam3:local
```

Health check the wrapper any time:

```bash
npm run sam3:health     # JSON: { ok, device, load_time_s, init_error }
```

In the UI, flip the **Detector** radio to *SAM 3*. Saved rows get a
green `sam3` badge.

### Apple Silicon notes

The wrapper installs two import-time shims so SAM 3 (which is officially
CUDA-only) runs on macOS arm64:

1. **Triton stub.** Both PyTorch's `_inductor` runtime and SAM 3's
   tracker / perflib code do `import triton` at module load.
   Triton has no macOS wheel, so we register a fake module (with
   `backends.compiler` and `compiler.compiler` submodules) that
   satisfies the import without providing real kernels. Image
   inference doesn't call any of them.

2. **CUDA → MPS redirect.** SAM 3 has hardcoded `device="cuda"` in a
   handful of places (`position_encoding.py`, `decoder.py`,
   `io_utils.py`). The shim wraps `torch.zeros` / `ones` / `empty` /
   `Tensor.cuda` / `Module.cuda` / `.to(...)` to silently rewrite
   `"cuda"` to `"mps"` when no real CUDA is present.

You'll see two `[sam3] installed ...` log lines on startup confirming
the shims fired.

---

## Running with SAM 3 (Modal — scale-out)

For citywide sweeps where you want parallelism and don't want to babysit
a laptop GPU, deploy the same contract to Modal Labs:

```bash
pip install modal
modal token new
modal deploy inference/sam3_modal.py             # prints a URL when done
```

Paste the URL into `.env.local`:

```
SAM3_ENDPOINT_URL=https://<yourorg>--streetview-sam3-sam3-predict.modal.run
```

Restart the server. Same UI, same wire contract — Modal's GPUs replace
your laptop's. Roughly **$0.80 / hour** while actively serving on an L4;
~$0.0001 per frame at typical batch sizes.

> The Modal recipe has explicit `TODO(verify-against-repo)` markers
> for the SAM 3 import + predictor signatures. The HTTP wire is stable;
> only the inner inference call needs to be reconciled with the
> upstream README before the endpoint returns real detections.

---

## Features

### Navigation

- **Interactive Street View panorama** powered by Maps JS, scoped to
  Accra by default but the panorama works anywhere with coverage.
- **Address / coord jump** at the top — paste `lat, lng` (e.g.
  `5.5561, -0.1825`) or any free-form address. The geocoder is biased
  to the Accra bounding box and Ghana region so short queries resolve
  locally.
- The resolved point is **snapped to the nearest pano** within 500 m
  before the panorama moves, so you never land on a coord without
  Street View coverage.

### Manual capture

- Detector toggle (**Claude / SAM 3**), persisted in `localStorage`.
  SAM 3 grays out automatically if `SAM3_ENDPOINT_URL` isn't set.
- **Capture & Analyze** runs the live `(lat, lng, heading, pitch, fov)`
  through the chosen detector. The captured JPEG and verdict appear in
  the *Current Frame* panel.
- **Save to DB** persists with the live `pano_id` from
  `panorama.getPano()` so the CSV's `p_id` field is always populated.

### Explore mode

Two ways to define the area:

- **Radius** — a center coordinate and a radius in meters
  (50–3000 m, default 200 m).
- **4 corners (bounding box)** — top-left / top-right / bottom-left /
  bottom-right, each accepting either coords or an address. Tilted
  quadrilaterals are supported.

Plus shared knobs:

- **Max panos** — hard cap so a runaway BFS can't burn through your
  Maps quota or Anthropic credits unsupervised.
- **Estimate panos** — does a metadata-only BFS scan (no images, no
  analysis, no save) and reports how many panos sit inside the area
  + projected cost at 4 headings × current detector. Use this to size
  *Max panos* before committing real spend.

While running:

- Live counters: `Batch`, `Panos visited / queued`, `Frames`, `AC found`
  (frames-with-AC and total units summed across them), `Elapsed`,
  `Tokens` (Claude only — `input / output` cumulative).
- The visible panorama jumps to each pano as it's analyzed, so you
  watch the walk happen.
- Per-frame thumbnail + verdict in *Current Frame* panel.
- Scrolling *log* of every analysis with timestamp, verdict, and a
  truncated `pano_id_heading` label.
- **Stop** sets an abort flag; the loop exits at the next heading
  boundary.

### Real-time monitoring + replay

- **Click any log entry** during or after a run → modal opens with the
  full-size captured JPEG, all view params (lat/lng/pano_id/heading/
  pitch/fov), the verdict, and the Claude reasoning text + token usage.
- **Click any saved-detection card** → same modal, fetched fresh from
  `/api/detections/:id` so it works after page reload.
- **Exploration batches** panel lists every batch ever recorded with
  per-batch stats (panos, frames, AC count, timestamp, detectors).
  Refresh button on the right.
- **View on map** on any batch → Google Map modal showing each pano as a
  numbered marker (BFS visit order), connected by a polyline along the
  walk path. Markers are color-coded:
  - 🟢 green — at least one frame at this pano had AC
  - ⚪ grey — no AC found across all frames
  - ⬛ dark — only no-imagery placeholders
- Marker click → opens the same detail modal as everywhere else, so
  you can inspect any historical exploration the same way you inspect
  a live one.

### Persistence and export

- **Local SQLite** at `poc.db` (override with `POC_DB_PATH=...` for
  ephemeral test runs). Schema covers coordinates in GeoJSON
  `[lng, lat]` order, all view params, the saved JPEG path, the
  detector used, and the batch id.
- **`/api/export.csv`** emits the schema you asked for:
  ```
  o_id, p_id, zone, longitude, latitude, ac, ac_count, batch_id
  ```
  - `o_id` — autoincrement detection id
  - `p_id` — `<pano_id>_<rounded heading>` (e.g.
    `Cb1d8e_180`); empty for legacy rows captured before pano_id was
    plumbed through
  - `zone` — left blank until the city is gridded
  - `longitude` / `latitude` — camera coords at capture time
  - `ac` — `"yes"` / `"no"` string
  - `ac_count` — integer; per-frame, see *Caveats* below
  - `batch_id` — integer for explore-mode rows, empty for one-offs
- The **Export CSV** button on the right pulls down the full file with
  a `Content-Disposition: attachment; filename="ac-detections-<date>.csv"`.

### Detector pluggability

`detectors.js` keeps the surface tiny:

```js
export const DETECTORS = {
  claude: analyzeWithClaude,
  sam3:   analyzeWithSam3,
};
```

Both functions take an image buffer and return a uniform shape, so
adding a third detector (Gemini, a fine-tuned YOLO, a custom hybrid)
is one entry in the map plus an env-variable hook.

---

## Project layout

```
streetview-inspector/
├── server.js                  # Express server, Static API proxy, save/list/export endpoints
├── db.js                      # SQLite schema + migrations (POC_DB_PATH override)
├── detectors.js               # analyzeWithClaude / analyzeWithSam3 — uniform return shape
├── public/
│   ├── index.html             # Layout, modals, explore form
│   ├── app.js                 # Panorama, jump, manual capture, explore BFS, modals, map
│   └── styles.css             # Dark theme, modal stacking, map legend
├── inference/
│   ├── sam3_local.py          # FastAPI wrapper, MPS shim, triton stub
│   ├── sam3_modal.py          # Modal Labs deployment recipe
│   ├── setup.sh               # Creates inference/.venv with all deps
│   └── README.md              # SAM 3 setup details + troubleshooting
├── captures/                  # gitignored — runtime JPEGs from /api/analyze
├── poc.db                     # gitignored — SQLite file, default location
└── .env.local                 # gitignored — API keys + optional overrides
```

---

## Caveats and known limitations

- **Per-frame AC counts can double-count physical units.** Each frame
  is analyzed independently, and a unit on the corner of a building
  can appear in two adjacent 90°-FOV captures. Naive
  `SUM(ac_count) GROUP BY pano_id` will overcount. Cross-frame dedup
  via mask/world-coord projection is future work — see the SAM 3
  discussion in the project history for the intended approach.
- **Trajectory map doesn't draw the search bounds.** Markers + polyline
  show what was visited, but the polygon/circle that defined the area
  isn't painted on the map. Easy follow-up: persist `batch_bounds` JSON
  on each row and outline it on the map.
- **SAM 3 marker click picks the most informative frame.** When a pano
  has 4 frames analyzed, the trajectory map's marker click opens the
  highest-priority frame (any-AC > none > skipped). To inspect every
  heading at a pano, use the *Saved detections* list, which is
  frame-level.
- **No retry on transient errors.** A failed `/api/analyze` during
  explore mode logs an `error` row and continues; nothing re-runs.
- **Single-threaded explore loop.** Sequential by design so the
  real-time UI stays predictable and the pano graph isn't expanded
  past `Max panos`. Concurrency is a future tuning knob.

---

## License

MIT-style POC code. Note that:

- Google Maps Platform API usage is governed by Google's terms.
- Anthropic API usage is governed by Anthropic's terms.
- SAM 3 weights are governed by Meta's facebook/sam3 license — confirm
  it's compatible with your use case before deploying.
- Captured Street View imagery is © Google. Don't redistribute the
  raw JPEGs; the derived AC-detection data is yours.
