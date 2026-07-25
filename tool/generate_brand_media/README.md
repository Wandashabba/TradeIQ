# generate_brand_media

Build-time generator for TradeIQ's brand illustration candidates (Imagen via
the Gemini API). **The app never calls a generative API at runtime** — no
keys in the client, no latency, no per-view billing. This script runs on a
developer machine, its output is curated by a human, and only the curated
files are ever committed.

## Run

```sh
GEMINI_API_KEY=<your key> node generate.mjs
```

- Node >= 18, zero npm dependencies.
- Writes 2 candidates per prompt to `out/<slug>-<n>.png` (`out/` is
  gitignored — candidates are never committed).
- Never hardcode or commit the key; the script reads it from the environment
  only.

## Curation workflow (human, deliberate)

1. Run the script; open `out/` and look at every candidate.
2. Pick **one** image per slug — or none, if nothing is good enough. Bad art
   is worse than no art; the text-only empty state is a fine fallback.
3. Copy the pick to `app/assets/images/brand/<slug>.png`
   (e.g. `app/assets/images/brand/tasks-all-clear.png`).
4. Add the file to the `flutter: assets:` list in `app/pubspec.yaml`.
5. Set the matching path constant in `app/lib/core/brand_media.dart`
   (each field is `null` until its image is curated).
6. Commit the asset + pubspec + `brand_media.dart` together.

## Video takes (Veo) — manual, optional

Extra ambient splash/sign-in video takes are a **manual** step, not scripted
here: generate with a Veo model (e.g. `veo-3.0-generate-001` — see
<https://ai.google.dev/gemini-api/docs/video>) in AI Studio, curate the same
way, and place under `app/assets/videos/`. Video candidates are large and
need human judgment per take; a batch script would just burn quota.

## Honesty rule (non-negotiable)

Generated imagery appears **only** on empty states, the splash/sign-in
ambience, and the menu-sheet header. **Never on data rows** — a row's
imagery is evidence (a captured shelf photo); generated art there would
counterfeit it.
