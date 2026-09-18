# Torchlight Aisle

The TradeIQ design system. One token source, three skins, two typefaces, and
one rule about the colour amber that explains most of the others.

Trade marketing happens in badly lit rooms — a spaza in Tembisa during Stage 6,
a forecourt cold-room at 05:40, a Boxer back aisle with the fluorescents off to
save load. In all of them the shelf is found by light. So darkness here is the
site, not the style, and the single amber is the torch. Outside, the sun is the
torch, the UI becomes ink on white, and amber becomes a block you press.

Everything below is enforced by tests in
`app/test/core/theme/torchlight/`. Where this document and the code disagree,
the code is right and this document is a bug.

---

## 1. Where the tokens live

```
app/lib/core/theme/torchlight/
  tiq_skin.dart        TiqSkin — the ThemeExtension. context.skin reads it.
  tiq_palette.dart     TiqPalette — every colour token, three value sets.
  tiq_space.dart       TiqSpace, TiqRadii, TiqDepth, TiqMotion, TiqDensity.
  tiq_type.dart        TiqType, TiqTypeToken, TiqFonts — the type scale.
  tiq_text_scale.dart  TiqTextScale + the two scoping widgets.
  tiq_contrast.dart    The declared contrast contract and the banned pairings.
```

```dart
final skin = context.skin;

skin.palette.ink1          // colours
skin.space.gutter          // spacing, density-aware
TiqSpace.s4                // the raw scale step, when you need a constant
skin.radii.panel           // geometry
skin.depth.shadows         // what this skin may cast
skin.motion.resolve(d)     // Duration.zero when motion is off
skin.text.body.style(color: skin.palette.ink1)
```

A skin is **a value set, not a code path**. Every difference between Night, Day
and Veld is a different `TiqPalette` / `TiqType` / `TiqDepth` handed to the same
constructor. If you find yourself writing `if (skin.mode == SkinMode.veld)` in a
widget, the thing you want is a token that does not exist yet — add it.

---

## 2. The palette

Every hex below is a token. Ratios are measured, not asserted:
`torchlight_contrast_test.dart` recomputes all 63 declared pairings on every
run.

### Grounds and surfaces

| Token | Night | Day | Veld | Use |
|---|---|---|---|---|
| `ground` | `#0B1017` | `#EEE9DF` | `#FFFFFF` | App ground, full bleed. Veld is pure white, not Palladian: every point of luminance counts at 40% backlight in highveld sun. |
| `vignette` | `#0F1620` | `#E6E0D4` | `#FFFFFF` | Midpoint stop of the ground's letterbox falloff and the plate's edge-dissolve. Four even stops, because two band on a 6-bit panel. |
| `well` | `#141D27` | `#E2DBCC` | `#FFFFFF` | Recessed: input troughs, nav-bar body, queue chips, mono blocks. |
| `surface` | `#1B2632` | `#FAF7F2` | `#FFFFFF` | The one panel surface: the answer's instrument panel, forms, sheets. |
| `raised` | `#22303E` | `#F4F0E8` | `#FFFFFF` | Stat-tile cells, scrub readouts, the question bubble. |
| `lifted` | `#2C3B4D` | `#2C3B4D` | `#1B2632` | Pressed/hover, chart bar tracks. On Day it is the nav-active ink block. |

Veld collapses every recessed and raised token onto white on purpose. A
1.12–1.24:1 fill step is one or two quantisation levels on a budget LCD in
sunlight — it is not a cue, so Veld does not pretend it is one and uses a 2px
border instead.

### Edges

| Token | Night | Day | Veld | Use |
|---|---|---|---|---|
| `hairline` | `#3A4B60` | `#DED7C9` | `#1B2632` | **Decorative only**: section rules, list separators, gridlines. Deliberately under 3:1 (2.14 / 1.18). Never the sole identifier of anything, and never the only cue that two regions differ. |
| `edgeStructure` | `#5B718A` | `#857C6B` | `#1B2632` | The compliant edge for **containers**: panel outlines, sheet edges. ≥3:1 on the fill it bounds and the ground it sits on. |
| `edgeControl` | `#7C93AC` | `#6E6657` | `#1B2632` | The compliant edge for **controls**: outlined chips, troughs, ghost buttons. Louder than a container edge on purpose — controls outrank containers. |

> **Correction to the spec.** The design document gave `edgeStructure` as
> `#5A7088` and described it as "tuned to exactly 3.00:1" on `surface`. It
> measures **2.9987:1** and therefore misses WCAG 1.4.11 — on the single most
> used structural edge in Night. The token is `#5B718A`, the minimum step up the
> same hue line, which measures 3.05:1 on `surface` and 3.79:1 on `ground`.

### Ink

| Token | Night | Day | Veld | Use |
|---|---|---|---|---|
| `ink1` | `#EEE9DF` | `#1B2632` | `#0E141A` | Body and headline text, hero figures, the focus bar fill on light grounds. |
| `ink2` | `#C9C1B1` | `#4A4437` | `#4A4437` | Secondary: reasons, subtitles, chip labels, eyebrows. |
| `ink3` | `#A79E8C` | `#676052` | `#4A4437` | Tertiary/meta: timestamps, units, axis labels, source lines. |
| `navInkInactive` | `#8AA0B8` | `#6E6657` | `#4A4437` | Inactive tab-bar icon and label — real text at 6.32:1 on the nav body, not a ghost. |
| `inkMute` | `#4C6079` | `#9B917F` | `#4A4437` | **Disabled only.** Deliberately sub-AA on Night and Day: 1.4.3 exempts disabled controls and a disabled control must look disabled. Veld has no such thing — outdoors nothing is allowed under 9:1. |

Warm off-white ink on a cool navy-black ground is the deliberate move. It is
what makes Night look lit rather than switched off.

### Amber — emitted light, never a label

| Token | Value | Use |
|---|---|---|
| `flame300` | `#8A4A12` | The **only** amber legal as text on a light ground. 5.66:1 on Palladian. |
| `flame500` | `#F79742` | Pressed amber block; second stop of the strip-light gradient. |
| `flame600` | `#FFB162` | The signature (Burning Flame). Its role changes by skin; its hex never does. |
| `flame700` | `#FFCB94` | Amber as text on dark, focus rings, the hot end of a bloom. 12.92:1 on Night ground. |
| `flame900` | `#FFF1DE` | The white-hot core stop of a glow gradient. **Never ink on an amber fill.** |
| `onAmber` | `#0B1017` / `#1B2632` / `#0E141A` | The ink that goes on an amber block. |
| `amberPressed` / `onAmberPressed` | `#F79742` + dark / **`#1B2632` + white** in Veld | The held-down state. |
| `TiqPalette.glowAmber` | `#FFF1DE@0.55 → #FFB162@0.30 → transparent` | Every bloom, as gradient stops. |

> **Correction to the spec.** The document declares "there is no token in Veld
> below 9:1 for text" and separately gives Veld's pressed amber block as
> veld-ink on `flame-500` at **8.34:1**. Both cannot be true. Veld does not
> lighten on press: it inverts to the ink block with white on it (15.33:1),
> which is also the only press cue Veld can afford — it has no glow, no shadow
> and no gradient to spend.

### Severity, comparison, data

| Token | Night | Day | Veld | Use |
|---|---|---|---|---|
| `good` | `#6FE0AE` | `#14664A` | `#0F5039` | On target. Outline + filled circle. |
| `goodSolid` / `onGoodSolid` | `#C9F5E1` + ground | `#0F5039` + white | same as Day | Solid success block. |
| `bad` | `#FF7D8C` | `#8C1B2C` | `#7A0F22` | Watch: 1px outline, `bad` ink, half-filled triangle. |
| `badSolid` / `onBadSolid` | `#E23C55` + ground | `#7A0F22` + white | same as Day | Critical: solid block, filled triangle, 3px left bar. |
| `comparison` | `#E08E71` | `#A35139` | `#A35139` | Competitor share, prior period, benchmark. Also the held/queued warm neutral. **Never a severity.** |
| `comparisonWash` | `#7A3A28` | `#F7DCD2` | `#F7DCD2` | Wash behind a "held" chip; the 2px edge on an underexposed photo. |
| `chartNeutral` | `#8B8271` | `#676052` | `#4A4437` | The fill of every non-focus bar and series. |
| `plateCeiling` | `#474747` | — | — | The maximum luminance any pixel of a baked photographic plate may reach. Enforced server-side; a contrast floor, not a decoration. |

`chartNeutral` exists because Burning Flame and Oatmeal have **identical**
relative luminance — 1.00:1. They are the same bar in greyscale, in
deuteranopia, in print and on a sun-washed panel. That pairing is banned; see §7.

**There is no `warn` token.** Severity abandons amber's hue band entirely.

---

## 3. The amber law

> **Burning Flame is a light source, never a label. Amber tells you where to
> look; it never tells you how bad something is.**

1. **Night.** Amber appears only as emitted light: a strip light on a plate, a
   1–2px rim, an underline, a focus ring, the active-tab underbar, a target
   tick, a stroke-weight line series, and exactly **one** focus fill per chart —
   the single bar the answer's sentence is about. Never a chip background, never
   a repeated series fill, never a status word's colour, never a badge, never an
   icon tint on a list row, and never the caret on a severity-coded delta.
   Budget is declared per screen and counted, not asserted.

2. **Day and Veld.** On light grounds amber inverts from light to ink-carrier,
   and **there is exactly one amber block per screen: the primary commit
   action.** Torch-on is a filled Abyssal block with an amber glyph and the word
   ON. "You are here" is an Abyssal disc with a white ring — amber leaves the
   map entirely. The ranked-bar focus channel is `ink1` fill plus a marker plus
   weight. The live pulse is a pulsing `lifted` dot plus the word Live.
   `skin.amberIsInk` is the token that carries this.

3. **Severity never uses amber.** One hue, two commitment levels, plus a glyph
   silhouette, plus a declared `semanticLabel`. Intensity carries urgency, not
   hue — which is how instrumentation has always worked, and which frees the
   whole 25–45° band for the brand.

4. **Truffle is the comparison series.** Amber is us, lit; Truffle is them,
   unlit earth. Our series is a solid amber stroke, theirs a dashed
   `comparison`. The dashed/solid distinction is **mandatory**: simulated
   deuteranopia puts the two 1.41:1 apart, so the stroke pattern is doing all
   the work. A legend showing swatch **and** pattern renders on every chart,
   every time.

5. **Where hue is the only channel, hue is replaced.** Every amber focus object
   additionally carries shape and weight. Diverging negatives are hatched
   (45° hard-stop gradient stripes — still no blur), because `bad` against
   `chartNeutral` is 1.55:1 true and 1.26:1 in protanopia.

6. **The one semantic amber is motion-coded and Night-only.** A pulsing amber
   dot on the 3200ms loop means "happening right now". A static amber is brand;
   a breathing amber is live. It degrades to a filled square plus the word
   "Live" under reduce-motion and for screen readers. Deliberately **not**
   applied to skeletons: loading is not live.

---

## 4. Type

Two faces, and a law that divides them.

- **Onest** — the prose face. One bundled variable font,
  `assets/fonts/Onest-Variable.ttf` (193 KB, wght 100–900, no italic). Flutter
  maps `FontWeight` onto the wght axis, so no static instances ship.
- **JetBrains Mono** — the figure and identifier face.

> **Onest must never render a figure or a code.** It has no slashed zero, its
> digits are proportional unless `tnum` is switched on, and its capital I and
> lowercase l are identical shapes. None of that matters in a sentence; all of
> it matters in an outlet code, a GTIN, an order ref or a column of stock
> counts. Every `figure` and `identifier` role resolves to JetBrains Mono with
> `FontFeature.tabularFigures()`; every `prose` role resolves to Onest.
> `torchlight_type_test.dart` asserts both directions, so this is not a
> convention.

Size / weight / line-height / tracking. Tracking is stated as a percentage of
the size, because that is the only form that survives a size change.

| Role | Kind | Console | Field | Veld |
|---|---|---|---|---|
| `heroFigure` | figure | 72 / 600 / 0.92 / −2.5% | same | 72 / 700 / 0.97 / −2.0% |
| `heroFigureCompact` | figure | 56 / 600 / 0.95 / −2.0% | same | 56 / 700 / 1.00 / −1.5% |
| `display` | prose | 40 / 600 / 1.00 / −1.5% | same | 40 / 700 / 1.05 / −1.0% |
| `figureL` | figure | 32 / 600 / 1.05 / −1.0% | same | 32 / 700 / 1.10 / −0.5% |
| `figureM` | figure | 22 / 600 / 1.10 / −0.5% | same | **24** / 700 / 1.15 |
| `figureS` | figure | 16 / 600 / 1.20 | same | 16 / 700 / 1.25 / +0.5% |
| `titleL` | prose | 20 / 600 / 1.25 / −0.5% | **24** / 600 / 1.25 | 24 / 700 / 1.30 |
| `titleM` | prose | 16 / 600 / 1.30 / −0.25% | same | **18** / 700 / 1.35 / +0.25% |
| `headlineAnswer` | prose | 22 / 600 / 1.35 / −0.5%, max 32em | same | 22 / 700 / 1.40 |
| `body` | prose | 14 / 400 / 1.55 | **15** / 400 / 1.50 | **17** / 600 / 1.55 / +0.5% |
| `bodyStrong` | prose | 14 / 600 / 1.55 | 15 / 600 / 1.50 | 17 / 700 / 1.55 / +0.5% |
| `label` | prose | 13 / 500 / 1.35 / +0.5% | same | **16** / 600 / 1.40 / +1.0% |
| `eyebrow` | prose | 11 / 700 / 1.10 / +8%, uppercase | same | 13 / 700 / 1.15 / +8% |
| `meta` | prose | 12 / 400 / 1.40 | same | **14** / 600 / 1.45 / +0.5% |
| `axisLabel` | **figure** | 12 / 400 / 1.40 | same | 14 / 600 / 1.45 / +0.5% |
| `monoIdent` | **identifier** | 13 / 500 / 1.30 / +1% | same | 16 / 600 / 1.35 / +1% |

`axisLabel` is split out from `meta` for one reason: a chart axis label is a
numeral, and numerals are mono. `meta` keeps the prose jobs — timestamps read as
language, source lines are language.

The `eyebrow` has exactly two jobs: the plate kicker and the stat-tile label. A
section marker is a knocked-out rule at `titleM`, not an uppercase kicker.

Veld's steps are **declared scale members**, not "one stop up". A stop invents a
17px that collides with two existing roles.

### PDF export

`package:pdf` parses `glyf` outlines and ignores a variable font's `gvar`
deltas, so it cannot use `Onest-Variable.ttf` — every weight would render at
400. Three static instances at wght 400/500/700, subset to Latin + Latin-Ext
plus the punctuation and currency the formatters emit, ship as plain assets
(`Onest-Pdf-400/500/700.ttf`, ~50 KB each) and are declared outside the `fonts:`
section so the engine never resolves a screen to them. Regenerate with
`tool/build_pdf_fonts.sh`.

---

## 5. Text scaling

The audit found **no** `textScale` handling anywhere in the app. That is not
"the default is fine" — it means nobody had looked.

1. **Clamp at 2.0**, in every density. Not 1.3 and not 1.6: a ceiling below 2.0
   on body text is a WCAG 1.4.4 failure wearing a layout argument. Wrap the app
   once in `TiqTextScaleScope`.
2. **Layouts absorb it.** The hero cluster is a `Wrap` so the delta drops to its
   own line. A 2×2 stat grid collapses to 1×4 on a `LayoutBuilder` width
   threshold — not on a scale guess. The hero uses the glyph-count rule and then
   `FittedBox(fit: BoxFit.scaleDown)`.
3. **One documented exception.** `heroFigure` caps at 1.6, because above that no
   fitting rule saves a 72px number on a 360dp screen. The cap lives on the
   token (`TiqTypeToken.maxTextScale`), visible to anyone reading the scale, and
   is applied by wrapping that one widget in `TiqRoleTextScale`. Adding a second
   capped role is a policy change and the test will say so.

Tested at 1.0×, 1.3× and 2.0×, in all three skins, on a 360dp phone.

---

## 6. Spacing, radii, depth, motion

**Spacing — base 4.** `s1…s11` = 4, 8, 12, 16, 20, 24, 32, 40, 56, 72, 96. **No
other value exists.** This replaces the raw-numeric `EdgeInsets` the audit found
in 96 files.

| | gutter | gutter ≥1080 | row min | block gap | intra-block | tap target | primary action |
|---|---|---|---|---|---|---|---|
| Console | 20 | 40 | 44 | 24 | 12 | 44 | 44 |
| Field | 20 | 20 | 64 | 32 | 16 | 48 | 56 |
| Veld | 24 | 24 | 64 | 40 | 20 | 56 | 64 |

Veld is **single-density by construction**: `TiqSkin.veld()` takes no density
argument, so `Veld × Console` has no spelling. A manager who opens the app
outdoors gets Veld, and that is correct — outdoors nobody is doing analysis.

**Radii — four materials, four radii.** `rule` 0 (rules and dividers), `chip` 6
(chips, outlined pills, ladder glyph tiles), `control` 10 (buttons, thumbnails),
`panel` 14 (the instrument panel, forms, sheets), `plate` 20 (photographic
plates). An input is a trough: `radii.input` is 10 at the **bottom** corners and
0 at the top — a trough holds at the bottom. Veld squares everything to 0.

**The 999 pill radius is gone.** It existed only for the active-tab pill, which
no longer exists. If you cannot name which of the four materials a surface is,
it does not get a radius.

**Depth — five levels, governed by a device floor.** No surface may rely on a
fill step alone to be perceived.

- **L0** ground, no edge.
- **L1** `well`, inset, no edge — it is allowed to recede, that is its job.
- **L2** `surface` + a 1px `edgeStructure` outline, plus a decorative
  `depth.litRim` on top of it.
- **L3** `raised`, used only **inside** an L2 that already has an edge, divided
  by hairlines.
- **L4** emitted: any fill plus an amber gradient bloom. Reserved for the
  plate's strip light, the active-tab underbar and the one focus bar in a chart
  — never more than two L4 objects on screen.

Night casts **no drop shadows** (black on black is invisible; the audit's 34
ad-hoc `BoxShadow`s all go). Day casts exactly three — `sh1 0 1 2 .06`,
`sh2 0 4 12 .08`, `sh3 0 12 32 .12`. Veld casts none, allows no gradients, and
its `borderWidth` is 2.

**Glow is never a blur.** Every bloom is a `BoxDecoration(gradient:)` with alpha
stops. Zero `BackdropFilter`, zero `ShaderMask`, zero `ImageFiltered`, zero
`saveLayer` outside Flutter's own. A gradient is the blur of a line, at zero
cost, painted inside the existing draw call.

**Motion.** 120 press · 200 enter (40ms stagger) · 320 reveal · 600 count-up and
busy · 1400 skeleton rule · 3200 live pulse. Curves: enter
`cubic-bezier(0.05,0.70,0.10,1.00)`, exit `(0.30,0.00,0.80,0.15)`, state
`(0.20,0.00,0.00,1.00)`, count-up ease-out-quart. One application-wide `Ticker`
with three subscribers. `skin.motion.resolve(d)` returns `Duration.zero` when
motion is off, so no caller has to branch — and Veld's motion is off.

---

## 7. Banned pairings

Declared in `TorchlightContrast.banned` and asserted. A banned pairing is not
simply an absent one: its ratio is recomputed on every run and the test fails if
it ever becomes legal, so a ban cannot survive as folklore after someone moves a
token — and nobody can "fix" the ban by reintroducing the pairing.

| Skin | Pairing | Measures | Needs | Use instead |
|---|---|---|---|---|
| Night | `flame600` and `ink2` as adjacent bar fills | **1.00:1** | 3.0 | `chartNeutral` for every non-focus bar. |
| Night | `flame900` ink on a pressed `flame500` block | **2.00:1** | 4.5 | `onAmberPressed` — the ink stays dark through the press. |
| Day | `flame600` as text on Palladian | **1.48:1** | 4.5 | `flame300`. |
| Day | `edgeStructure` on the Day `well` | **2.99:1** | 3.0 | `edgeControl`, or move the container out of the well. |
| Veld | `flame600` as a line, icon, border or word on white | **1.79:1** | 3.0 | A solid amber block carrying `onAmber`, once per screen — or `ink1` for a line or a word. |

Every ban names a replacement. A ban without one is a dead end and someone will
walk back into it.

Three pairings are declared **exempt** rather than banned — `hairline` on ground
in both lit skins, and `inkMute` on `surface`. An exemption must carry a written
reason and must actually be quiet: the test fails an "exempt" pairing that
measures over 3:1, because that is a token being used for the wrong job.

---

## 8. The guards

All in `app/test/core/theme/torchlight/`, run by `flutter test` in
`app-ci.yml` — no new tooling, no analyzer plugin, no second analysis pass.

| Test | What it catches |
|---|---|
| `torchlight_lint_test.dart` | A file in `lib/features/**` that gains a `Color(0x…)`, a `Colors.*` or a bare `TextStyle(`. Ledger in `torchlight_style_debt.dart`; the scanner itself is tested against known-bad and known-good source, because a guard that cannot fail is not a guard. |
| `torchlight_type_test.dart` | A figure or identifier role set in Onest; a prose role set in mono; a missing `tnum`; Onest declared with a weight (which pins the variable axis); Onest shipping without an `fvar` table; Inter creeping back into the bundle. |
| `torchlight_contrast_test.dart` | All 63 declared pairings against their floor, every banned pairing still failing, the Veld 9:1/15:1 floors, the ink ramp stepping down, control edges outranking container edges, and every spec-stated ratio recomputed to two decimals. |
| `torchlight_render_test.dart` | All three skins building a theme and painting a screen that touches every token; `lerp` across a mode change; `Veld × Console` being unconstructible; the spacing scale being base-4 with no twelfth step; the shim mapping. |
| `torchlight_text_scale_test.dart` | The clamp, the one documented exception, and all three skins at 1.0×/1.3×/2.0× on a 360dp phone. |
| `onest_font_test.dart` | Every theme asking for Onest; the Torchlight themes setting figures in mono; the PDF instances shipping and being static. |
| `torchlight_generated_contrast_test.dart` | ~1000 generated ink x role x fill pairings across all five skin/density combinations; the Vienot deuteranopia and protanopia simulations against the ruling's own figures; every declared series pair carrying a non-colour channel. |
| `torchlight_amber_lint_test.dart` | A `flame*` token named anywhere under `lib/` outside the five-file emitter allowlist. |
| `torchlight_glyph_coverage_test.dart` | A character the formatters or the translations emit that is missing from the committed PDF font subsets; a new reference to U+25B2 or U+25BC. |
| `core/design/*_test.dart` | The six foundations: the ladder and both of its failure modes, the formatter in both locales, the figure primitive's four states and its measured fitting, the motion boolean, the two hard hatch rules, and the amber pixel census against three fixture routes. |

### The style ratchet

`lib/features/**` carried **477** hardcoded style decisions when this landed —
409 bare `TextStyle(`, 38 raw `Color(0x…)`, 30 `Colors.*` — across 74 of 133
files. The ledger records them per file. The ratchet is **one-sided**: a file
may not gain a violation, and a file not in the ledger may not have one at all.
A file that loses violations passes and the test prints the number to lower the
ledger to — a two-sided ratchet would fail a PR for making things better.

`Colors.transparent` is allowed: it is the absence of a colour, not a choice of
one. A single line can be excused with
`// torchlight-ignore: <reason>` on that line. The marker is deliberately
verbose.

---

## 9. The six foundations

Phase 0 of the component system. These are patterns, not pixels: nothing here
is wired into a route, and **no screen changed appearance when they landed**.
Phase 1 builds components against them.

```
app/lib/core/design/
  torch_scope.dart     TorchScope — the amber allocator.
  tiq_number.dart      TiqNumber — the one locale formatter.
  figure_slot.dart     FigureSlot — the one figure primitive.
  motion_budget.dart   MotionBudget — one `still` boolean.
  hatch_paint.dart     HatchPaint — the four patterns.
```

### 9.1 TorchScope — the amber allocator

**What it is.** An `InheritedWidget` at the top of a route that decides which
of the objects asking to be lit actually are. A screen gets a countable number
of lights and a fixed ladder decides who gets them, because "use amber
sparingly" is a sentence nobody can fail and every audit of this app found the
same twelve amber objects on one screen.

The arithmetic: **Night = 2** — the nav's active tab is slot 1 whenever the nav
renders, content gets one grant on a tabbed route and two on an untabbed one.
**Day and Veld = 1**, and it is the primary commit block; zero when nothing is
armed. The nav is *counted*, not exempt — kit called it "reserved" and manager
called it "exempt", both produce the same number, and "counted" is the honest
word.

The ladder: `primaryCommit` → `plateStripLight` → `chartFocus` → `navCircle`
(only on a route with no primary) → `textFieldFocus` → `livePulse` (presence
only, one per route). There is no `meterTick` rung: a target tick is an
annotation, an annotation is a label, and it is ink-1 everywhere.

**How to use it.**

```dart
TorchScope(
  skin: context.skin,
  phase: 'loaded',            // resolved per route × phase, never per frame
  navRenders: true,
  tabbedRoute: true,
  beneathSheet: false,
  claims: <TorchClaim>[
    TorchClaim.primaryCommit('check-in'),
    TorchClaim.chartFocus('worst-outlet', subject: true),  // one per route
  ],
  child: …,
)
```

An emitter asks and takes its ink form when the answer is false:

```dart
color: TorchScope.lit(context, 'check-in')
    ? skin.palette.flame600
    : skin.palette.chartNeutral,
```

Outside a scope the answer is `false`. Unlit is always the safe render, so a
Phase 1 golden with no route around it does not paint amber by default.

On a **light ground** the ladder has one rung. Every other claim is denied with
`notAmberOnLightGround` — not because it lost, but because it has a non-amber
form there and takes it: the nav tab is an Abyssal block, the focus bar is
ink-1, "you are here" is a disc with a white ring, the live pulse is a `lifted`
dot and the word Live.

While a **modal sheet** is up, `beneathSheet: true` extinguishes every amber on
the route beneath — the nav tab drops to its ink form and the plate's light goes
off. That is what lets the scrim stay at 72% and keep the held work visible
behind it instead of hiding it under 88%.

**Failure.** Over-claiming throws a `FlutterError` in debug, with the whole
ladder and the `subject: true` override printed. In release the surplus loses in
ladder order and the frame renders correctly lit — a design rule must never
throw in front of a user in a back aisle during Stage 6. A test exercises the
release path by setting `debugTorchAssertOverClaim = false`; that flag is the
one documented way past the assert and is deliberately not a constructor
argument.

**How to add to it.** A new rung means a new `TorchClaimKind` and a new line in
`_rung`. That is a change to the law, not a feature: argue it in the PR, add the
case to `torch_scope_test.dart`'s ladder group, and say which surface's claim it
settles.

### 9.2 TiqNumber + FigureSlot — the formatter and the figure

**What they are.** One locale formatter and one figure primitive. Before them
there was `NumberFormat('#,##0.#', 'en_US')` in one file and sixty-nine
`toStringAsFixed` calls in thirty-three others, which is why the same number
could print three ways on three screens and a fourth way in the PDF.

`TiqNumber` owns grouping, the decimal mark, the currency affix and the sign:

| | en | af |
|---|---|---|
| `format(1284990.5)` | `1,284,990.5` | `1 284 990,5` (U+00A0 groups) |
| `format(-31, unit: percent)` | `−31%` | `−31%` |
| `format(1284990, unit: currency)` | `R 1,284,990` | `R 1 284 990` |

Every minus is **U+2212**, never a hyphen-minus: a hyphen is a word-joiner,
it is narrower than a digit, and in a tabular column it makes a negative number
look indented rather than negative. A value that rounds to zero prints unsigned,
because `−0%` is a movement that did not happen. Separators are *declared* here
rather than read from CLDR at runtime — a CLDR bump that moved English onto
space-and-comma would change every screen in the product without a line of the
diff being about it.

`FigureSlot` sets it:

```dart
FigureSlot(
  value: outlet.score,          // null is a state, not an absence
  role: skin.text.figureL,      // must be a figure or identifier role
  fit: <TiqTypeToken>[skin.text.heroFigure, skin.text.heroFigureCompact],
  unit: TiqUnit.percent,        // or .currency, or TiqUnit.worded(l10n.points)
  decimals: metric.decimals,    // the metric's precision, not the value's
  state: FigureState.lowSample,
  semanticsLabel: l10n.noVisitsInWindow,   // required for every unknown state
)
```

Four things it owns:

1. **Two faces.** The digits are JetBrains Mono with `tnum`; the affixes are
   Onest at zero tracking, because `R` and `pts` are language.
2. **Unknown versus zero.** A measured zero renders `0`, keeps its place and is
   never suppressed. A null renders an em dash in **ink-3, at the figure's own
   role and face**, with the unit suppressed and `allowsDelta: false` — a delta
   never stands beside nothing. A low sample keeps the figure at **ink-2**, the
   caller outlines the fill, and the delta goes, for a thin baseline too.
3. **Measured fitting.** Candidate roles are laid out with a `TextPainter` at
   the live `TextScaler`, affixes included; the first that fits wins. There is
   no `FittedBox` anywhere in it — optically shrinking one figure in a baseline
   row breaks the row's baseline, which is what a tabular column exists to
   prevent.
4. **The scale cap.** `hero.figure` caps at 1.6×, applied through
   `TextScaler.clamp`, never as a factor multiplied into a font size.

**How to add to it.** A new locale is a `TiqNumberSymbols` member plus a row in
`tiq_number_test.dart`. A new unit is a `TiqUnit` member only if it is a
*symbol*; a worded unit is a translated string and arrives through
`TiqUnit.worded` already localised — this class does not own language.

> **Not yet migrated.** The 69 `toStringAsFixed` call sites and
> `rich_figures.dart`'s `NumberFormat` are unchanged. Repointing them is a
> visible change — Afrikaans separators, a true minus where a hyphen is today —
> and Phase 0 changes no screen. They move with their screens, in §11's
> migration order.

### 9.3 MotionBudget — one `still` boolean

**What it is.** `disableAnimations ∨ Veld ∨ powerSave`, resolved once and read
by everything that moves. The audit found four ambient loops, two of which
honoured reduce-motion and none of which knew about Veld.

```dart
if (MotionBudget.of(context).still) {
  // the resting frame: a filled square and the word "Live"
} else {
  // the 3200ms pulse
}
```

Durations do not need it — `skin.motion.resolve(d)` already returns
`Duration.zero`. This is for what a duration cannot express: whether to start a
`Ticker` at all, and which of two *different* renderings to paint.
`MotionBudgetScope` pins a value for a test or a golden; there is no scope in
the running app, because this is a value that can always be computed.

> **`powerSave` is `false`, and that is #407.** Reading the OS battery-saver
> state needs about forty lines of platform code on each of Android and iOS and
> nobody has written them. The input is wired open, with the ticket number on
> it, so the sentence "motion stops in battery saver" is a promise with an owner
> rather than a line in a design document. `motion_budget_test.dart` asserts
> both the `false` and the `TODO(#407)`, so the day the channel lands the test
> is what says "now wire it".

### 9.4 HatchPaint — the four patterns

**What it is.** A hatch says what a fill cannot: *not measured*, *negative*,
*low sample*, *provisional*. It is the second channel where there is no room for
a word, and it survives greyscale, both dichromacies and a sun-washed panel —
which a hue does not.

| Pattern | Looks like | Says |
|---|---|---|
| `notMeasured` | 45° falling stripes, full track width | Nobody scored this dimension |
| `negative` | 45° rising stripes | The wrong side of a diverging axis |
| `lowSampleOutline` | fill removed, outline only | A real number, too thin a sample |
| `provisionalOutlineDots` | outline plus dots | Server-stamped provisional, console only |

```dart
HatchPaint.paint(canvas, trackRect, HatchPaint.spec(skin, HatchPattern.notMeasured));
```

Two rules, both asserted:

1. **Never inside a glyph.** A 3dp stripe inside a 28dp section-state tile
   aliases to a flat grey disc at 40% backlight — the half-disc it must not
   resemble. "Can't confirm" is a fourth *silhouette* (a ring with a 2px
   diagonal bar), not a hatched third one. The `insideGlyph:` argument exists so
   that a caller who believes it has a good reason has to write the word down,
   and then the assert says no.
2. **Never on a mark under 4dp.** Below that the stripe pitch and the mark are
   the same size and the pattern reads as noise or as a solid.

A hatch in a list row is **painter lines**, not a gradient decoration: a
gradient inside a `ListView.builder` row is a new `Paint` and a new shader per
row per scroll frame. There is no gradient form in the registry, so there is
nothing to reach for by mistake, and `hatch_paint_test.dart` asserts the source
file does not contain the word.

**How to add to it.** A fifth pattern is a `HatchPattern` member, a `spec` case
and a row in the pinned list in `hatch_paint_test.dart`. Ask first whether the
thing wants a fourth *silhouette* instead — a shape beats a texture at 40%
backlight every time.

### 9.5 The generated contrast test

`torchlight_contrast_test.dart` checks the pairings a person wrote down.
`torchlight_generated_contrast_test.dart` checks the ones nobody did.

**The sweep.** `TorchlightContrast.generatedFor(skin)` produces every ink × type
role × fill pairing for one skin at one density, with the floor taken from the
role that is actually set in the ink — `meta` at 12px needs 4.5:1 and
`figure.l` at 32px needs 3.0:1, so the same two colours are two different
verdicts. It runs over all five skin × density combinations the app can build
(Veld appears once: `Veld × Console` has no spelling), which is about a thousand
pairings.

Veld's 9:1 / 15:1 floors are now **tokens on the skin** — `skin.textFloor` and
`skin.borderFloor`, combined with the role's floor by `skin.floorFor` — rather
than an `if (mode == veld)` in the generator. A skin is a value set, not a code
path.

**The colour-vision passes.** `simulateVision(color, filter)` implements
greyscale plus Viénot–Brettel–Mollon deuteranopia and protanopia in
`tiq_contrast.dart`, beside `contrastRatio`, so production and test cannot
compute them differently. The implementation reproduces the ruling's own
figures: Burning Flame against Truffle is **1.41:1** in deuteranopia, and `bad`
against `chartNeutral` is **1.55:1** true and **1.26:1** in protanopia. Both are
pinned.

Two findings worth keeping in mind:

- **Greyscale is not a separate pass.** WCAG contrast is already a
  luminance-only metric, so a pair that measures 1.42:1 in colour measures
  1.42:1 in greyscale *by construction*. There is no hue rescue available
  anywhere in this system. That is the finding, not a flaw in the test.
- **Dichromacy sometimes separates a pair better.** A protanope sees crimson far
  darker, so `good` against `badSolid` is 4.10:1 under protanopia against 2.58:1
  in normal vision — and it is no help at all, because the pair is still one hue
  with two silhouettes doing the work. The test therefore validates the
  *matrices* (a neutral grey must map to itself; the red and green channels must
  collapse onto one confusion line) rather than asserting a direction.

**The registry.** `TorchlightContrast.seriesPairs` is twenty-seven declared
pairs — nine in each skin — of things a reader has to tell apart, each carrying
the `SeparationChannel`s that tell them apart when hue cannot (`shape`,
`weight`, `dash`, `hatch`, `outline`, `word`, `position`) and one sentence of
why. A pair with an empty channel set fails. "It also has a different shape" is
a claim, and a claim in a review comment does not survive the component being
rewritten.

**How to add to it.** A new ink or fill goes in the matrices inside
`generatedFor`. A new pair of things a reader must distinguish goes in
`seriesPairs` with its channels and its sentence.

### 9.6 The amber golden harness

**What it is.** `TorchScope` asserts on what a route *claims*.
`test/core/design/amber_golden.dart` counts what it *painted*. Both are needed:
a widget can light itself without asking the allocator, a decoration can bloom
where nobody declared an object, and a shim can hand an old screen a flame token
through a mapping table.

```dart
await pumpAmberRoute(tester, skin: TiqSkin.night(), child: const DashboardFixture());
final census = await amberCensus(tester);
expectWithinAmberBudget(census, skin, route: 'dashboard', phase: 'loaded');
```

It renders the route into a `RepaintBoundary` at a pinned 360×720 and
devicePixelRatio 1.0, classifies every pixel, finds the eight-connected regions
of the flame-hued ones, discards anything under 12px as an anti-aliasing speck,
and fails when the count exceeds the skin's budget.

**What counts as flame-hued:** hue 20°–48°, value ≥ 0.90, saturation ≥ 0.12.
That box contains `flame500/600/700/900` and excludes every warm neutral the
system paints beside them. The value floor is what makes it a census of
*emitted* light: `flame300` is amber but it is ink (value 0.54), and the tail of
a bloom composited at 30% over the Night ground lands at value 0.33. Counting a
halo as a second light is how a budget check gets switched off for being noisy.

Oatmeal sits one hundredth of a saturation point outside the box, which is not a
coincidence — Burning Flame and Oatmeal have identical relative luminance. A
test asserts the classification of every token in every skin, so if a palette
change ever moves Oatmeal into the box that fails first and says so.

**It is proven to fail.** Three fixtures ship: `AmberDashboardFixture` (tabbed,
nav + primary — 2 in Night, 1 on a light ground), `AmberVisitFixture` (untabbed,
plate + live pulse — 2 in Night, 0 on a light ground) and
`AmberOverLitFixture`, which paints four amber blocks directly without ever
speaking to the allocator. Tests assert that the census counts all four, that
`expectWithinAmberBudget` throws on it in Night *and* on a light ground, and
that a route under an open sheet paints zero. The pixel arithmetic itself —
touching blocks are one object, a diagonal rim is one object, a 4px speck is
none — is checked against buffers built by hand.

**How to add to it.** A Phase 1 component's golden pumps its route through
`pumpAmberRoute` and asserts both `expectWithinAmberBudget` *and* the exact
count the ladder predicted. "Under budget" also passes for a screen that lost
its light entirely.

### 9.7 The other two guards

**The codepoint guard** (`torchlight_glyph_coverage_test.dart`) parses the
`cmap` tables of the three committed `Onest-Pdf-*.ttf` files — the binaries, not
`tool/build_pdf_fonts.sh`'s intentions, because a range added to the script and
never re-run is a range that does not exist — and asserts that every character
`TiqNumber` emits and every character in both `.arb` files is really in all
three weights. `package:pdf` does not fall back and does not draw tofu: a
missing glyph is simply absent from the report, which is how a delta arrow left
every export in #401 and was found by a customer.

It also ratchets **U+25B2 / U+25BC**, which Onest has never had at any weight.
Five call sites survive, in a ledger with the component that deletes each:
`delta_pill.dart` (2), `rich_figures.dart` (2), `artifact_pdf.dart` (1). No file
may gain one and a file not in the ledger may not have one at all. It is a
ratchet rather than a flat ban because removing those five lines changes what is
on screen, and Phase 0 changes nothing on screen; Phase 1's **Delta** draws the
triangle as a path and empties the ledger.

**The amber lint** (`torchlight_amber_lint_test.dart`) forbids `flame300/500/
600/700/900`, `glowAmber`, `amberPressed`, `onAmber` and `onAmberPressed`
anywhere under `lib/` outside a five-file allowlist, all of them in
`core/theme/`. A widget that reaches for `flame600` directly has not asked
whether it is lit, which means it is lit on every route including the ones that
already have two lights. Adding a path to
`TorchlightScanner.amberAllowlist` is adding an emitter to the system: argue it
in the PR. Phase 1 adds four — the nav pill, the primary button, the plate and
the chart focus bar.

---

## 10. Adding a token

1. **Check it is a token and not a value.** If it is used once, it is a value.
   If two components would disagree about it, it is a token.
2. Add the field to `TiqPalette` (or `TiqSpace` / `TiqType` / `TiqDepth`), with
   a doc comment saying what it is **for** — the job, not the colour.
3. Give it a value in **all three** value sets. Veld usually wants a different
   answer, not a lighter one: it has no shadow, no gradient and no fill step to
   spend, so ask what carries the meaning when those are gone.
4. Extend `lerp` (and `copyWith` on `TiqSkin` if you added a top-level field).
5. **Declare its contrast.** Add a `ContrastPairing` to
   `TorchlightContrast.declared` for every surface it can sit on, with the role
   that says what floor applies. If it cannot clear the floor, change the value
   — not the floor.
6. If a pairing is forbidden, add a `BannedPairing` with the replacement. Add
   its label to the pinned list in `torchlight_contrast_test.dart`, so deleting
   a ban is a visible edit rather than an omission.
7. If it is a type role, declare its `TiqTypeKind`. `figure` and `identifier`
   get JetBrains Mono and tabular figures automatically; `prose` gets Onest. Add
   the name to the pinned set in `torchlight_type_test.dart`.
8. Add it to the table in this document.

---

## 11. Migration status

The five old colour sources — `TiqColors`, `LumenPalette`, `LumenGlass`,
`AppColors`, `status_pill_colors.dart` — are all `@Deprecated`, all still
registered, and all still work. Sixty screens are painted in Lumen Glass and
they keep rendering exactly as they did.

- `AppTheme.dark()` / `AppTheme.light()` are unchanged Lumen themes, except that
  they now also register a `TiqSkin`, so **`context.skin` resolves everywhere
  today**. The only visible change is the typeface: Onest replaces Inter.
- `AppTheme.night()`, `AppTheme.day()` and `AppTheme.veld()` are the Torchlight
  themes. They register both a `TiqSkin` and a `TiqColors` derived from it by
  `TiqColors.fromSkin`, so a screen still on `context.colors` renders in
  Torchlight tokens the moment it is pointed at one.
- `TiqColors.fromSkin` is the whole slot-by-slot mapping table, in one place. It
  maps each old slot onto the token that now carries that **job** — `warn` lands
  on `bad`, because there is no amber warning in TradeIQ and a shim that
  invented one would reintroduce the collision this direction exists to kill.

`deprecated_member_use_from_same_package` is set to `ignore` in
`analysis_options.yaml`: ~400 infos in front of `flutter analyze` would turn the
one signal CI has into noise. The annotation still strikes the member through in
the editor and carries its message; the ratchet is what enforces the migration.
Turn the diagnostic back on when the last shim call site is gone, and delete the
shims.

**Sequencing.** `GlassPane` is in 61 files and is deleted when its call sites are
empty, not first. Golden infrastructure lands **Night only**, before any feature
screen is ported; Day follows per component; **Veld is sequenced last**, after
Night and Day are shipped and stable, because it has the fewest users per day
and the highest per-component tax — and shipping it third means its goldens are
written against components that have stopped moving.

---

## 12. Phase 1 — the frame and the buttons

The chrome and the button family. Nothing in `lib/features/**` changed when they
landed: these are components with tests and no call sites, exactly as Phase 0
was patterns with no pixels.

```
app/lib/core/widgets/torchlight/
  button/
    torch_press.dart        press, focus ring, haptics, the Abyssal helpers
    torch_button.dart       heights, label roles, busy dots, BarNote, triangle
    primary_button.dart     TorchPrimaryButton
    secondary_button.dart   TorchSecondaryButton
    tertiary_button.dart    TorchTertiaryButton
    destructive_button.dart TorchDestructiveButton
    icon_button.dart        TorchIconButton
    buttons.dart            the barrel
  chrome/
    torch_shell.dart        TorchShell (agent / console)
    app_header.dart         TorchAppHeader
    nav_pill.dart           TorchNavPill, TorchNavSlot
    nav_circle.dart         TorchNavCircle
    skin_cycle.dart         TorchSkinCycle
    thumb_zone.dart         TorchThumbZone
    chip_wrap.dart          TorchChipWrap (the header's two-row cap)
    chrome.dart             the barrel
```

### 12.1 The button family

| | geometry | amber |
|---|---|---|
| `TorchPrimaryButton` | 56 Field / 44 Console / 64 Veld, radius 10, full width | `TorchClaim.primaryCommit`, rung 1 |
| `TorchSecondaryButton` | the same, ghost | none |
| `TorchTertiaryButton` | text + rule, 48dp target (56 Veld) | none |
| `TorchDestructiveButton` | the same block, 2px crimson outline | none, categorically |
| `TorchIconButton` | 48 square (44 Console, 56 Veld), 24dp glyph | none |

Every height is a **minimum**. At 2.0× the label wraps and the button grows to
intrinsic height with 16dp of vertical padding; nothing is pinned and nothing is
ellipsised, because a verb the reader cannot read is not a verb.

```dart
TorchPrimaryButton(
  claimId: 'submit-visit',     // the id the route declared to TorchScope
  label: 'Send this visit',    // a verb phrase, never "OK"
  onPressed: _submit,          // null disables it
  blockedReason: 'Stock and Pricing still need finishing.',
  busy: false,
  icon: Icons.send,            // optional 18dp leading glyph
)
```

`blockedReason` is **required when the button is disabled** — an assertion, not
a convention. A disabled primary renders a `TorchBarNote` **above** it at meta
12/400 ink-3, wrapping, never truncated, as a live region. Kit drew the note
beneath the button; the agent surface drew it above and is right, because the
primary lives at the bottom edge of a 96dp thumb zone and there is nothing under
it to put a sentence in.

The primary's label role is a lookup, not a new token: unify §1.7's **16/600
Field, 14/600 Console, 18/700 Veld** lands exactly on Field `title.m`, Console
`body.strong` and Veld `title.m`.

**Night's granted form is a lit block, not an amber one.** `lifted` fill, a
flame-600 rim, Palladian label, and a 2dp `TiqPalette.glowAmber` gradient bleed
along the top inside edge. The rim is **2px** where the spec says 1: a 1px stroke
on a radius-10 shoulder anti-aliases to about 72% value at the corners, under the
census's 0.90 floor, so the census reads a 1px rim as four separate lights and a
correctly built commit button fails the budget it obeys. A rim the enforcement
mechanism cannot count is a rim that fails the law it exists to serve.

**Day and Veld** are a solid `flame600` block carrying `onAmber`, with a real
`ink1` edge — an amber block on Palladian is 1.6:1 against its own ground and
nothing here is identified by a fill alone. **Pressed** floods to `amberPressed`
with `onAmberPressed`: in Night that is flame-500 with `#0B1017` at 8.59:1,
exactly as §1.7 asks. Veld does *not* lighten — `#0E141A` on flame-500 is 8.34:1,
under the 9:1 floor Veld declares for every word it shows — so its press inverts
to the ink block with white on it. That is the palette's own argued answer and it
is read from the token rather than restated in the widget.

`TorchIconButton` takes `semanticLabel` as a **required constructor argument**
and asserts it is not empty. That is the whole reason it exists in a codebase
that already had `IconButton`: the audit found 26 unlabelled ones. Toggled-on is
a solid Abyssal block plus **the state word** (`stateWord`, required when
`toggledOn`) plus `Semantics(toggled: true)` — never a colour, and never a fill
step on its own. unify §1.23 is the one place the reconciled system corrects the
spec's own text, and this is where that correction lives.

### 12.2 Press, focus and haptics

`TorchPressable` is the one gesture wrapper. **Press is two channels**: a scale
to 0.98 (0.94 for a glyph target) at 120ms *plus* a fill change to a declared
token — and under reduce-motion the scale is dropped, so the fill is the channel
that always has to be there. Ghost controls also step their edge from 1px to 2px,
because Night's fill step is 1.67:1 on the ground and that is not enough on a
6-bit panel at 40% backlight.

`torchPressSurface(skin)` is the fill-and-ink pair: Night steps up to `lifted`,
Day steps down to `well`, and Veld — which has no fill steps at all, every one of
its surface tokens being white — inverts to the ink block with white on it.

`torchAbyssal(skin)` / `torchOnAbyssal(skin)` are the non-amber way this system
says *this one*: `lifted` in all three skins, carrying Palladian in Night and Day
(9.43:1) and white in Veld (15.33:1). `TiqSkin.onFill` cannot answer that,
because `lifted` is a dark **ground** in Night and a dark **ink block** in Day.

The keyboard focus ring is 2px flame-700 at a 2dp offset in Night, 2px ink-1 at
2dp in Day, 3px ink-1 at 3dp in Veld. It renders only under
`FocusHighlightMode.traditional` and is the one amber the ladder does not count,
by declaration — it never co-occurs with a touch frame and never appears for a
touch user.

`TorchBuzz` has four members and nothing else vibrates: `tick` (every ordinary
press), `success` (a completed commit), `warning` (a destructive first press, a
failure toast), `finding` (a zero that raises a task).

### 12.3 The chrome

```dart
TorchScope(
  skin: context.skin,
  phase: 'loaded',
  navRenders: TorchShell.navWillRender(context, hasNav: true),
  tabbedRoute: true,
  claims: <TorchClaim>[TorchNavCircle.claim('raise-task')],
  child: TorchShell(
    profile: TorchShellProfile.console,
    header: TorchAppHeader(
      title: 'The Floor',
      facts: <String>['Gauteng', '74 outlets', 'updated 09:12'],
      back: TorchIconButton(…),          // at most one, optional
      trailing: skinCycleButton,         // EXACTLY one, or none
      flagChips: <Widget>[…],            // the mark set's chips go here
    ),
    navPill: TorchNavPill(slots: managerSlots, activeIndex: 0, onSelect: go),
    navCircle: TorchNavCircle(claimId: 'raise-task', …),
    children: <Widget>[…],               // the body
  ),
)
```

**`TorchShell`** — gutter, header, scroll frame, bottom region. The console
profile paints the letterbox falloff (four stops, one gradient, one draw call;
none in Veld) and widens the gutter past 1080dp. Three bottom regions, one of
which always applies:

1. **tab root** — a floating 64dp row, inset 16, 20dp above the safe area: the
   pill, a 12dp gap, the 64dp circle. In Veld the bar **docks** and the circle
   floats above its trailing end.
2. **a screen with a primary** — a `TorchThumbZone`.
3. **neither** — a 76dp zone holding the skin cycle alone.

A nav and a thumb-zone primary on one route is an assertion failure: 64dp of nav
plus 96dp of thumb zone plus a safe area is a quarter of a 640dp screen given to
chrome. A primary that belongs on a tab root goes **in the body** ("Check in
here" on the next-up row), which is exactly the arrangement the amber census
measures.

The bottom region is a **sibling** of the scroll view, not an overlay. Overlaying
it would mean reserving a height computed from tokens, and at 2.0× the region is
taller than those tokens — which is how the last row of a list ends up under a
nav bar on exactly the devices whose readers need it most.

**`TorchAppHeader`** — no `AppBar`, no elevation, no fill that changes on scroll.
`trailing` is typed as a single `TorchIconButton` because the rule is *exactly
one*; on a tab root that one is the skin cycle. `facts` are joined by middots on
screen and read as a sentence by a screen reader.

unify §4 says headers cap at 40% of the viewport and then scroll. That is not
implemented as a runtime measurement that re-parents the header — it is four
caps that between them make the header small enough (title two lines, facts two
lines, chips two rows, and the header scrolls with the body so an *expanded* chip
list simply scrolls). `chrome_scale_test.dart` asserts the resulting height
against 256dp — Afrikaans, 2.0×, with a back button and four facts — so the
ceiling is a tested property rather than a promise.

`TorchChipWrap` is a real `RenderBox` rather than a `Wrap` in a clipped box,
because clipping hides the overflow without counting it and the count is what the
expander's label says. It publishes the hidden count through a `ValueNotifier`
after layout; the listener sits outside it, so a label change can never relayout
the rows that produced it. A chip that is not drawn is not announced either.

**`TorchNavPill`** — radius 999, 64 tall, inset 16, 20dp above the safe area,
`well` fully opaque, a 1px `edgeStructure` outline. **Four slots maximum**, which
is an assertion: at 360dp the bar has 252dp once the insets and the circle are
drawn, and five slots is 50dp each, under the tap-target floor before the active
pill takes its 6dp inset. Manager: Floor · Work · Ask · Menu. Agent: Today · My
work · Map · Me.

The active tab is a solid pill inset 6dp, 48 tall, radius 999 — `flame600` with
`#0B1017` at 10.65:1 in Night, a solid Abyssal block with Palladian or white ink
on a light ground, **never amber there**. **Veld docks the bar**: full bleed,
72dp, a 2px top border, radius 0, which also gives back 36dp of fold.

`TorchNavSlot` requires **both** `icon` and `activeIcon`. That is not decoration:
at 2.0× the bar goes icon-only, the label and its 700 weight disappear, and if
the glyph did not change then *selected* would be carried by the amber fill and
nothing else — a colour-only signal, on the screens whose readers asked for
bigger text.

**`TorchNavCircle`** — 64dp, outside the bar, a 12dp gap. It declares
`TorchClaim.navCircle`, rung 4, and the allocator denies it **outright** on any
route with a primary commit: a screen with a commit action on it is a screen
about that commit action. Whether it is the expected next move is carried by the
glyph (`icon` → `expectedIcon`, an outlined plus becoming a filled arrow) and by
the spoken label, before any fill changes — so the state survives greyscale, a
light ground where it is never amber at all, and a screen reader.

**`TorchSkinCycle`** — 56dp (64 Veld, 72 at 2.0×), three positions, each a
different glyph: sun is Veld, paper is Day, moon is Night. `TorchSkinCycle.next`
is Day → Veld → Night → Day. Its `semanticLabel` names the **next** state, and it
is a live region. Per unify §1.2 it is *not* on the nav row: on a tab root it is
the header's single trailing icon button, and on every other screen it is at the
leading end of the thumb zone.

**`TorchThumbZone`** — 96dp (112 Veld, 160 with a second action), a rule across
the full bleed, the cycle at the leading gutter and the primary beside it. The
second action sits **above** the primary: the thumb rests at the bottom of the
screen and a control that throws work away must never be the bottom-most thing
under it.

### 12.4 How amber is claimed rather than painted

No component in this folder decides that it is lit. Each asks
`TorchScope.lit(context, id)` and paints its granted or its denied form. The
route declares the claims; the allocator resolves them once per route × phase.

* `TorchPrimaryButton.claim(id)` → `TorchClaim.primaryCommit`, rung 1.
* `TorchNavCircle.claim(id)` → `TorchClaim.navCircle`, rung 4, declared **only**
  when the action is the expected next move.
* The nav's active tab is not declared by anyone: `TorchScope` adds
  `TorchScope.navActiveTabId` itself whenever `navRenders` is true, so no route
  can forget to count the chrome it did not draw. The pill reads that same id.

**The keyboard.** `TorchShell.navWillRender(context, hasNav:)` is the single
answer the shell and the route's `TorchScope` both read. With the keyboard up it
is false, the nav is not built, and the grant it was holding returns to the
content — which is what makes "a focused text field plus a lit primary" exactly
two rather than three.

**The census.** `chrome_amber_test.dart` renders a Night tab root with the nav on
screen, a primary in its body and a nav circle declared, and counts the flame-hued
connected regions in the frame:

| skin | lit objects | which |
|---|---|---|
| Night | **2** | the nav's active tab, and the primary's rim |
| Day | **1** | the primary block; the tab is Abyssal |
| Veld | **1** | the primary block; the bar is docked and its tab is ink |
| any, beneath a sheet | **0** | every amber on the route goes out |

The nav circle asked and lost with `TorchDenial.circleWithPrimary` in all three.

Building that test found a real bug in the Phase 0 harness, and it is fixed here:
dark ink on an amber block leaves amber showing through the counter of every `o`,
the inside of every outlined glyph and the middle of the one in "10", and an
eight-connected walk counted each of those as a separate light. A nav tab whose
slot said "Today" counted as four. `censusOfPixels` now drops a region whose
bounds are contained by another region's — *a lit object is not enclosed by
another lit object* — while two lights that merely overlap still count as two.

Four files are added to `TorchlightScanner.amberAllowlist`: `primary_button`,
`nav_pill`, `nav_circle` and `torch_press`. Every one of them asks the allocator
first.

### 12.5 The nav bar at 2.0× text, and in Veld

At build the bar lays out **every localised label** with a `TextPainter`, at the
ambient scaler, against the slot width it actually has. If any one of them
overflows, the whole bar goes **icon-only — all four, never a mixed bar and never
a two-row grid**. A 132dp nav grid plus a circle plus a thumb zone is a third of
a 640dp screen; and a bar that kept three labels and dropped one would have
dropped the longest word, which is to say always the same language.

The failure case is Afrikaans and it is real. `nav_afrikaans_test.dart` uses the
app's own strings — Vandag, Jou werk, Kaart, Ek — and at 360dp they all go, at
1.3× they all go, at 720dp they all come back, and a bar with three one-letter
labels and one "Kompetisies" loses all four. Icon-only is a **layout** decision
and never an accessibility one: each slot keeps its full
`"Vandag, tab 1 of 4"` semantics and its selected flag.

Glyphs scale with the text because in an icon-only bar the glyph is the only
thing carrying the destination — 24dp up to a cap of 32, because the active pill
is 48 and a 48dp glyph in a 48dp pill is a glyph with no pill around it. The bar
is 64dp **minimum** and grows only when measured content will not fit.

In Veld the bar docks: full bleed, 72dp, a 2px `#1B2632` top border, radius 0,
its active slot a solid ink block with white on it at 15.33:1, targets at 56, no
gradient, no shadow, no rim, no bloom. `chrome_golden_test.dart` asserts all
three — no `BackdropFilter`, `ImageFiltered` or `ShaderMask` anywhere in the
frame, no `BoxShadow` in Night or Veld, and no gradient at all in Veld.

### 12.6 What a migrating screen has to do

Phase 1 migrates no screens. When one is migrated, it does four things:

1. **Wrap the route in a `TorchScope`** and declare its claims, with
   `navRenders: TorchShell.navWillRender(context, hasNav: …)` and `tabbedRoute`
   telling the truth. The claim set comes from the view model at construction and
   per declared phase — never recomputed per frame, because a grant that is
   recomputed while a thumb scrolls is a grant that blinks.
2. **Replace `Scaffold` + `AppBar` with `TorchShell` + `TorchAppHeader`**, and
   pick one bottom region: a nav pill (tab root), a primary in the thumb zone, or
   the skin-cycle-only zone. Move any ad-hoc bottom button into the zone. A
   primary that has to coexist with a nav goes in the body.
3. **Replace every button.** `ElevatedButton`/`AgentButton` → `TorchPrimaryButton`
   with a `claimId` and — for every disabled state — a `blockedReason`.
   `OutlinedButton` → secondary, `TextButton` → tertiary, `IconButton` →
   `TorchIconButton` with a real `semanticLabel` naming the destination
   ("Back to Today", never "Back").
4. **Add the screen to the amber census.** One fixture, one route × phase × skin,
   `expectWithinAmberBudget`. A screen with no golden is a screen the law is not
   enforced on.

The two pieces the chrome deliberately does **not** own, and which a migrating
screen gets from its siblings: the flag chips that go in
`TorchAppHeader.flagChips` (the mark set) and the rows that go in
`TorchShell.children` (the soft row).
