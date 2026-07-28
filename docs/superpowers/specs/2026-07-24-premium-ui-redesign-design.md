# Premium UI Redesign Design

**Ask:** make the app feel like a real product instead of an AI template, following four
Mobbin references the user supplied: a Coinbase/GOAT-style splash, a Stripe-style
dashboard, a Tide Guide-style map, and an Apple News-style floating bottom bar.

Every decision below was made interactively against rendered mockups
(`.superpowers/brainstorm/25570-1784882330/content/`, gitignored) — nothing here is
assumed. Where a decision reverses an earlier shipped one, the reversal is called out.

## Scope and decomposition

The user chose a **full sweep** — both manager web and agent mobile. That is too large
for one spec-plan cycle, so it ships as five sub-projects, each with its own plan and
PR(s). This spec fully designs sub-projects 1–4 and only *scopes* sub-project 5:

1. **Foundation + journey** — design tokens flip light-first; splash → sign-in flow;
   responsive nav (restyled sidebar + floating bottom bar).
2. **Manager dashboard** — the Stripe treatment.
3. **Maps** — the Tide Guide treatment (dashboard island + full-screen trail).
4. **Bar destinations + remaining manager screens + evidence thumbnails** — Tasks,
   Alerts, Menu sheet; batch restyle of everything else; real-photo thumbnails.
5. **Agent mobile** — scoped only. Inherits the brand foundation and splash pattern;
   its screens get their own reference round and spec (field UX — gloves, sunlight,
   one-handed — deserves its own brainstorm, and the user's references do not cover it).

## The theme architecture (decision: option A of three)

**Light console, dark islands.**

- The **default theme becomes light**: plane `#F7F8FA`, white cards, `#E3E5EA`
  hairlines, ink `#14161C`/`#5F6875`. The existing dark theme stays behind the
  existing toggle, untouched. The theme-persistence mechanism is unchanged.
- **Dark is reserved for three deliberate moments**: the splash, the sign-in, and the
  maps. The dark→light flip at auth success is the product's "arrival" moment.
- Accent everywhere is **TradeIQ blue `#0A6CF0`** — not Stripe's indigo. One accent,
  used sparingly: primary buttons, active nav pill, chart emphasis.
- **Reversal note:** on 2026-07-23 the maps were switched to light Positron tiles
  because the user disliked the dark map. The user has now explicitly chosen a dark
  map *style* (Tide Guide) — the earlier rejection was of the flat dark basemap, not
  of darkness itself. The reversal is intentional and user-directed.

## Sub-project 1 · Foundation + journey

### Tokens and chrome
- Light values already exist in `TiqColors.light` and pass contrast; the work is
  flipping the **default** (`ThemeMode.light` when nothing persisted) and tuning
  chrome toward Stripe: 8–12px radii, softer shadows (`0 1px 2px rgba(20,22,28,.05)`),
  fewer borders, more whitespace, larger quiet numbers (28–32px stat figures) over
  small muted labels (10–11px, letter-spaced).
- Inter stays (already bundled). No new fonts.

### Splash (decision: option B of three)
- `/` becomes a splash: the existing aisle video **dimmed under an 88–92% black
  overlay**, wordmark fades up. No Continue button.
- **Auto-advance after 5 seconds** to `/login`; **tap anywhere skips immediately**.
- `reduceMotion`: static first frame, no fades, same 5s/tap behaviour.
- **A restorable session skips sign-in**: splash → dashboard directly.
- **Timer/restore race, defined:** navigation happens at `max(5s, session-restore
  resolution)` — the splash never advances before 5s (brand moment holds) and never
  advances to the wrong destination because restore hadn't resolved. A tap during
  restore waits for resolution, then goes to the right place.
- Widget-test caveat (existing): no platform video in tests — the splash must render
  and auto-advance with the video absent.

### Sign-in (decision: hinge option A of two)
- Sign-in **stays dark**, continuous with the splash: same dimmed footage behind a
  restyled dark card (the current login is already dark; this is polish).
- Auth success crossfades into the light console — the one place the theme flips
  inside a session.

### Responsive navigation (floating bottom bar — decision: set A of three)
- **≥1080px**: the existing sidebar, restyled to the light chrome. No bottom bar.
- **<1080px**: sidebar disappears; an Apple News-style **floating pill bar** appears —
  blurred white (`rgba(255,255,255,.92)` + backdrop blur), hairline border, soft
  shadow, floating 12px off the bottom edge.
- Tabs: **Home · Tasks · Alerts · Map · Menu (☰)** — the "what needs me now" loop.
  Rejected: an Outlets/Orders commerce set (order-taking is half-built, #36), and the
  Apple News literal detached Search button (global search does not exist; building it
  inside a nav decision is scope creep — it can join the bar later as its own feature).
- Active tab sits in a blue pill (`#EAF2FF` bg, accent icon+label) that **slides**
  between tabs.
- **Menu (☰)** opens a bottom sheet over a dimmed, blurred backdrop: drag handle, the
  full destination list in the sidebar's existing groups (OPERATE / INSIGHT /
  CONFIGURE) as a two-column grid, then a housekeeping row — theme toggle, sign-out.

## Sub-project 2 · Manager dashboard (decision: treatment C, then C+v4B)

Layout stays the current dashboard's — same panels, same data, no logic changes. The
restyle:

- **Hero (execution score):** a "glass" card — soft blue gradient wash
  (`#F2F7FF → #FFFFFF`), 30–32px score, **delta pill** (`▲ 4.2 vs prior 30d`, green
  wash `#E7F5E7`/`#0B6B0B`), target as a dashed line labelled on a large gradient-area
  trend chart (2–2.5px line, area fading `#0A6CF0 28% → 0%`), endpoint dot.
- **KPI cards (iterated three times: icons proposed → real icons → icons removed):**
  label + number + delta pill + **gradient micro-trend** sparkline. **No icons** —
  explicitly removed by the user. The lagging metric's pill goes amber, not green.
- **Needs-attention card:** white card, count-first rows (colour-coded numeral + bold
  title + muted subtitle), "View all" in accent.
- **Filters:** territory dropdown + range chips as white pills, active chip solid blue.
- **Agent panel:** as shipped (map + list + footer), with the map island restyled per
  sub-project 3 and rows picking up the pill language.

### Chart rules (dataviz pass — binding on every chart in the app)
- Stat tiles for headline numbers; thin marks (2px lines); one axis, never dual.
- Legends whenever ≥2 series, selective direct labels, text in ink tokens never in
  series colour; recessive grid; hover tooltips on every plotted chart.
- Palette validated with the dataviz validator: light series set passes; the
  **amber↔green adjacent pair sits in the 6–8 ΔE CVD band and is legal only with
  secondary encoding** — any chart placing them adjacent must direct-label or gap
  them. TradeIQ's existing never-colour-alone rule (#144) already mandates this.

## Sub-project 3 · Maps (the Tide Guide treatment)

- **Basemap:** CARTO dark tiles under a **navy tint overlay** so the world reads deep
  blue, not grey — the Tide Guide ocean feel. (Implementation: dark_all tiles + a
  translucent navy colour layer; exact overlay opacity tuned visually at build.)
- **Pins glow:** radial blue discs with layered glow shadows, white rim; the
  current/last stop gets the brightest halo. Numbered stops keep their numerals.
- **Labels:** luminous light-blue (`#D9E6FF`) with heavy dark text-shadow — outlet
  name + check-in time under each pin. Place names muted (`#6D84A8`).
- **Chrome:** translucent dark top bar (title, agent, date chip in a blue-tinted
  pill); translucent bottom gradient carrying the legend and the OSM/CARTO
  attribution (licence requirement, unchanged).
- **Honesty rules survive the glamour — non-negotiable:** numbered sequence, dashed
  polylines meaning "inferred, not recorded" with the legend saying so in words,
  agent states distinguished by shape not colour alone, data age always visible.
- Applies to both the full-screen trail and the dashboard's map island (same world,
  panel-sized). The camera/scroll-wheel decisions from the July map work
  (`fitFor`, no `initialCameraFit`/`onMapReady`, `scrollWheelZoom` off on the
  embedded panel) are load-bearing and must not be unwound by the restyle.

## Sub-project 4 · Bar destinations, remaining screens, evidence imagery

### Tasks screen
- Filter chips with live counts (`Open · 15`, `Overdue · 3`, `Done`).
- White row-cards: task title, outlet + assignee muted line, **SLA pill** doing the
  status work — red `OVERDUE 2d`, amber `DUE TODAY`, muted `DUE FRI`, green `✓ DONE`.
  Words on every pill, never colour alone.

### Alerts screen
- Severity as a **coloured left edge** on the card *plus* the pill label.
- Unacked alerts carry inline actions: `Acknowledge` (accent), `View visit`.
- Acked alerts fade back (reduced opacity, muted `✓ ACKED` pill).

### Evidence thumbnails (decision: real photos, not generated art)
- Task and alert rows show a **thumbnail of the real captured shelf photo** where one
  exists: `Task.visitId` / `Alert.visitId` → `Visit` → `Photo` (linkage already in the
  schema). Tapping opens the full photo — the thumbnail *is* the evidence.
- **No photo → no thumbnail.** Never a placeholder image, never generated art on a
  data row. Rationale (user-agreed): generated imagery on data screens is the "AI
  template" feel this project exists to remove, and a pretty full-shelf illustration
  on an out-of-stock alert contradicts the alert.
- Perf note: photos are base64 in Postgres (~8MB rows, #65). Thumbnails must NOT
  fetch full photos per row — this needs a thumbnail endpoint or a deferred-load
  strategy decided at plan time for sub-project 4.

### Generated media (Gemini — build-time only)
- **Where:** illustrated empty states (tasks all-clear, no alerts, empty lists), extra
  ambient splash/sign-in video takes, the menu-sheet header. Nowhere that real data
  could stand instead.
- **How:** generated once with the user's Gemini key (Imagen for stills, Veo for
  video) via a repo script (`tool/generate_brand_media/`, run manually), then
  **curated by the user** and committed as bundled assets. The app never calls a
  generative API at runtime — no keys in the client, no latency, no per-view billing.
- Empty-state art direction: calm, brand-blue-tinted, abstract-retail; consistent
  series so screens feel related.

### Remaining manager screens (batch)
- Inherit the foundation automatically. Then batch passes restyle the shared widgets
  once (`console.dart` tables/panels, `worklist.dart` lists) so orders, outlets,
  territories, campaigns, etc. pick up cards/pills/spacing without per-screen work.
  Any screen needing real redesign gets its own mockup round then.

## Motion system (applies across sub-projects; every item `reduceMotion`-gated)

- Splash: wordmark fade-up; crossfade to sign-in.
- Sign-in → console: dark dissolves, light fades in, cards rise ~12px, ~40ms stagger.
- Stat tiles: numbers count up on first load (~600ms); delta pills pop in after.
- Charts: lines draw once left-to-right on entry; gradient fills fade in.
- Bottom bar: active pill slides between tabs; menu sheet springs up, scrim fades.
- Lists: rows cascade with a short stagger; acknowledging an alert collapses it.
- Maps: camera easing and one-shot at-store halo (as shipped) + a slow ambient
  breathing on pin glow (~2% opacity swing).
- Discipline: entrances are one-shot. The only sanctioned loops are two small,
  transient, reduceMotion-gated signals — the map pin-glow breathing above, and
  the sync-in-flight PulseDot (`agent_motion.dart`), which breathes *only* while
  a flush is actually in flight. Nothing loops on an idle, all-day dashboard;
  perpetual motion there becomes noise.

## Accessibility and honesty (carried forward, non-negotiable)

- State never by colour alone — pills carry words, pins carry shape/numerals (#144).
- Contrast: existing validated light tokens; every new pill wash pair must clear
  4.5:1 for its text (values in this spec chosen to comply; verify in review).
- `reduceMotion` yields a fully static UI except content itself.
- Data-age visibility and the inferred-route dashes are design features, not
  decoration; no restyle may remove them.

## Verification approach

- Widget tests keep behavioural coverage; visual claims are verified the way this
  project already does it: **build, run, screenshot in a real browser, and look** —
  including the splash timing (5s, tap-skip), the auth theme-flip, narrow-width bar
  behaviour, and both themes.
- Palette changes re-run the dataviz validator; motion re-tested under `reduceMotion`.

## Out of scope

- Agent mobile screens (sub-project 5 — own spec).
- Global search (candidate future bar item; not designed here).
- Any backend behaviour change beyond a photo-thumbnail read path (sub-project 4
  plan decides its shape).
- Dark-theme redesign: dark stays as-is behind the toggle; only its maps inherit the
  Tide Guide look (they are the same screens).
