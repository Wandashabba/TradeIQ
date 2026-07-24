# Premium UI Sub-project 3 — Tide Guide Maps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Both agent maps — the full-screen trail and the dashboard island — become the approved Tide Guide world: deep navy ground, glowing pins, luminous labels, with every honesty rule intact.

**Architecture:** `TiqTileLayer` flips to CARTO `dark_all` with a navy tint overlay layer (the "ocean" feel). Pins keep their numbering/state-glyph systems and gain a glow treatment; labels render under trail pins. The camera/scroll-wheel decisions from July (`fitFor` as camera source, no `initialCameraFit`/`onMapReady`, `scrollWheelZoom` off on the island) are load-bearing and MUST NOT be touched.

**Tech Stack:** Flutter + flutter_map 8.x; flutter_test; pinned Chrome-for-Testing 150.0.7871.129 for screenshots (today's system Chrome cannot render headless CanvasKit).

**Spec:** `docs/superpowers/specs/2026-07-24-premium-ui-redesign-design.md`, "Sub-project 3 · Maps". This REVERSES the 2026-07-23 light-Positron decision — user-directed (they picked the Tide Guide reference explicitly); the spec's reversal note covers it.

**Ordering note:** pulled forward ahead of the dashboard sub-project at the user's request — the map was their primary reference and shipping sub-1 without it read as a miss.

---

## Task 1: Dark basemap + navy overlay + glow primitives

**Files:**
- Modify: `app/lib/core/widgets/basemap.dart`
- Test: `app/test/core/widgets/basemap_test.dart` (create if absent; a widget test asserting the URL and overlay presence)

- [ ] **Step 1: Failing test** — pump a `FlutterMap` with `TiqTileLayer` + `TiqNavyTint` and assert: the `TileLayer.urlTemplate` contains `dark_all` (not `light_all`), and the tint layer renders an `IgnorePointer` with a `Color(0x668A9FD4)`-family navy wash. (Read the current file first; write assertions against the real widget tree.)

- [ ] **Step 2: Implement**
  - `TiqTileLayer._url` → `https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png`.
  - New `class TiqNavyTint` — an `IgnorePointer` over a full-size `DecoratedBox` with a radial navy gradient (centre `Color(0x3312294A)`, edges `Color(0x66081226)`) so the grey CARTO dark tiles read as the Tide Guide deep-blue world, vignetting slightly at the edges. Placed as a map child between tiles and any marker layer.
  - REWRITE the class doc comment: it currently records the 2026-07-23 "manager chose Positron" decision; it must now record the reversal — the user explicitly chose the Tide Guide dark treatment on 2026-07-24 (premium-ui spec, reversal note), and the earlier rejection was of a flat dark map, not this styled one.
  - Attribution text/widget unchanged (licence).

- [ ] **Step 3:** `flutter test test/core/widgets/ && flutter analyze` — green/clean. Commit: `feat(app): dark navy basemap world for the agent maps (premium-ui sub3)`.

## Task 2: Trail screen — glowing numbered pins + luminous labels + dark chrome

**Files:**
- Modify: `app/lib/features/agents/presentation/agent_trail_screen.dart`
- Modify: `app/test/features/agents/agent_trail_screen_test.dart`

- [ ] **Step 1: Failing tests** — update/add: (a) every stop marker still keyed `agent-stop-<agentId>-<i>` and still numbered; (b) each trail pin now renders a visible label containing the outlet name (find.textContaining per fixture outlet); (c) the LAST stop's pin carries the `agent-stop-last-halo` key (brightest halo) while non-last pins do not; (d) polylines remain dashed (`pattern.segments` non-null — existing test stays); (e) the legend still contains the inferred-route wording. Contrast guard: numeral (white) on the glow disc's core `Color(0xFF1F7AE0)` must clear 3:1 via the repo's `contrastRatio` helper — assert it in a plain test.

- [ ] **Step 2: Implement**
  - `_StopPin` → glowing disc: radial gradient `Color(0xFF7CC0FF)` → `Color(0xFF1F7AE0)`, white rim border 2px, `BoxShadow`s `0 0 22 6 rgba(64,156,255,.5)` + `0 0 44 12 rgba(64,156,255,.18)`; numeral white w800. Last stop: brighter core (`0xFF9FD4FF` → `0xFF3B93F5`) and stronger halo (`.65`/`.25`), keyed `agent-stop-last-halo`. Numbering carries sequence (honesty rule) — the halo is enhancement, not the only signal.
  - Marker child becomes pin + label column (Marker width ~128, height ~72, `alignment: Alignment.topCenter` so the pin sits on the point): label = outlet name (+ `HH:MM`) in `Color(0xFFD9E6FF)`, 11px w600, `shadows: [Shadow(blurRadius: 5, color: Colors.black)]`, maxLines 2, ellipsis.
  - Map children order: `TiqTileLayer` → `TiqNavyTint` → polylines → markers → attribution.
  - Polyline colour: `Color(0xFF4D9BFF)` at `.8` opacity (dashes unchanged).
  - `_TrailLegend`: translucent dark (`Color(0xCC050A16)`) with `Color(0xFF8FA5C6)` text; same wording. Keep ManagerScaffold, date picker, `fitFor` camera, day+points key — untouched.
  - Ambient glow breathing (the spec's ONLY looping animation): wrap the glow halo opacity in a slow repeating tween (~2400ms, swing ≈±3%), fully disabled under `reduceMotion(context)` (static at mid value). Keep it subtle — visible if you look, invisible if you don't.

- [ ] **Step 3:** `flutter test test/features/agents/ && flutter analyze` — green/clean. Commit: `feat(app): trail map joins the Tide Guide world (premium-ui sub3)`.

## Task 3: Dashboard island — same world at panel size

**Files:**
- Modify: `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart` (`_AgentMap`, `_AgentMapPin`, `_OutletBasePin`)
- Modify: `app/test/features/dashboard/agent_activity_panel_test.dart`

- [ ] **Step 1: Failing tests** — update/add: (a) island renders `TiqNavyTint`; (b) agent pins keep keys `agent-pin-<agentId>` and their DISTINCT state glyph shapes (existing glyph tests must keep passing — glyph-by-shape is the a11y contract); (c) outlet base pins remain visually subordinate (smaller size assertion) and keyed as today; (d) `scrollWheelZoom` absence guard keeps passing UNTOUCHED.

- [ ] **Step 2: Implement**
  - `_AgentMap` children gain `TiqNavyTint` after `TiqTileLayer`.
  - `_AgentMapPin`: state glyph (unchanged shape set) now sits on a glowing blue disc (same gradient family as trail pins, smaller: 30px, halo `0 0 14 3 rgba(64,156,255,.55)`), glyph in white. Re-run the repo's `contrastRatio` check for white-on-`0xFF1F7AE0` ≥3:1 in a test. List rows / `_agentStateVisual` for the SIDE LIST unchanged (they sit on the light card, not the map).
  - `_OutletBasePin`: dim navy-glow dot — `Color(0xFF39557E)` fill, faint halo `0 0 8 2 rgba(64,120,200,.35)`, same small size; still shape-distinct from agent pins (dot vs glyph disc).
  - Footer, truncation notice, camera, wheel-zoom flags: untouched.

- [ ] **Step 3:** `flutter test test/features/dashboard/ && flutter analyze` — green/clean. Commit: `feat(app): dashboard map island joins the Tide Guide world (premium-ui sub3)`.

## Task 4: Full verification + browser proof + PR update

- [ ] Full app suite + analyze at HEAD.
- [ ] Rebuild web; serve; drive **pinned Chrome-for-Testing 150.0.7871.129** (scratchpad `cft/`; today's system Chrome renders blank — proven earlier). Screenshots: (1) dashboard island in the light console — dark navy island, glowing state pins, dim outlet dots; (2) full-screen trail — navy world, glowing numbered pins with luminous labels, dashed blue lines, dark legend; (3) reduced-motion trail — glow static. Throwaway scratchpad Postgres pattern for the backend if Docker is still down; seed + today-visits so pins exist.
- [ ] LOOK at every screenshot before claiming success. Then push (updates PR #195's branch) and update the PR body: maps section shipped, ordering note (pulled ahead of dashboard at user request).

## Self-review notes
- Honesty rules preserved by construction: numerals (T2), dashed lines + legend wording (T2), glyph shapes (T3), data-age in the side list untouched (T3).
- The only loop is the glow breathing, reduceMotion-gated (T2) — spec's motion table.
- Camera/scroll decisions explicitly fenced off in every task.
- Names introduced: `TiqNavyTint`, key `agent-stop-last-halo` — used consistently above.
