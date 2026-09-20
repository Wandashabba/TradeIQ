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
| `chartNeutral` | `#A39887` | `#5C5648` | `#4A4437` | The fill of every non-focus bar and series. |
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
| `eyebrow` | prose | 11 / 700 / 1.10 / **+4%**, uppercase | same | 13 / 700 / 1.15 / +4% |
| `meta` | prose | 12 / 400 / 1.40 | same | **14** / 600 / 1.45 / +0.5% |
| `axisLabel` | **figure** | 12 / 400 / 1.40 | same | 14 / 600 / 1.45 / +0.5% |
| `monoIdent` | **identifier** | 13 / 500 / 1.30 / +1% | same | 16 / 600 / 1.35 / +1% |

`axisLabel` is split out from `meta` for one reason: a chart axis label is a
numeral, and numerals are mono. `meta` keeps the prose jobs — timestamps read as
language, source lines are language.

The `eyebrow` is legal in **three** places and no others: a stat tile's label, a
hero or plate figure's label, and a block label inside a panel ("WORST FIRST").
A screen-level section marker is a knocked-out rule at `titleM` in sentence
case, not an uppercase kicker.

Its tracking moved from **+8% to +4%** in Phase 1 (unify §1.4). Uppercase plus
tracking is the most space-hungry setting in the system and the eyebrow is a
stat tile's only label channel; at +8% the Afrikaans "BESKIKBAARHEID OP RAK"
took a third line on a 360dp phone at 1.0×, so the setting meant to make the
label compact was costing the tile its fold. Use the `Eyebrow` widget, which
uppercases for *display* and hands the sentence-case string to `Semantics` — a
`toUpperCase()` at the call site puts the uppercase in the data, where a screen
reader spells it out.

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
| Night | `flame600` and `ink2` as adjacent bar fills | **1.00:1** | 3.0 | `chartNeutral` `#A39887` for every non-focus bar. |
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
against `chartNeutral` is **1.16:1** true and **1.06:1** in protanopia. Both are
pinned. (The `bad`/`chartNeutral` pair measured 1.55 and 1.26 before Phase 1
moved the neutral to `#A39887`; the two hues converged, which makes the rising
hatch on a diverging negative more load-bearing, not less.)

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

## 9b. Phase 1 — the soft row

The first Phase 1 component, and the single most-used object in the product:
every list on all sixty screens is a stack of these.

```
app/lib/core/widgets/torchlight/row/
  row.dart            the barrel — import this
  soft_row.dart       SoftRow, SoftRowChevron, MiddleTruncatedText
  soft_row_spec.dart  SoftRowSpec — the resolved geometry, as a pure function
  row_marks.dart      RowMarkTile — the drawn state silhouettes
  outbox_row.dart     OutboxRow + PayloadSize          (#382)
  held_work_row.dart  HeldWorkRow                      (#391)
  decision_row.dart   DecisionRow
  person_row.dart     PersonRow                        (#399/#400)
```

**No screen consumes it yet.** Nothing under `lib/features/` changed when it
landed; screens adopt it one feature folder at a time, behind a green suite.

### Two forms, three densities

```dart
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

// A list row — flush, radius 0, separated by a 1px rule inset to the text edge.
SoftRow(
  density: SoftRowDensity.standard,        // compact 56 / standard 64 / tall 80
  title: outlet.name,
  titleTruncation: SoftRowTruncation.middle, // names and outlets only
  subtitle: l10n.metresAway(outlet.distance),
  meta: Text(l10n.lastVisited(outlet.lastVisit)),
  leading: const RowMarkTile(mark: RowMark.square),
  trailing: const SoftRowChevron(),
  severity: SoftRowSeverity.critical,
  severityLabel: l10n.severityCritical,     // required with a severity
  onTap: () => context.push(outlet.route),
  separator: isLast ? SoftRowSeparator.none : SoftRowSeparator.auto,
)

// A standalone row — radius 14, `surface` fill, 1px edgeStructure outline.
// Next-up card, day block, readiness block, outbox summary.
SoftRow(
  form: SoftRowForm.standalone,
  density: SoftRowDensity.tall,
  title: l10n.nextUp(outlet.name),
  subtitle: l10n.metresAway(outlet.distance),
  onTap: () => context.push(outlet.route),
)
```

### A row's own verbs — `actions` and `trailingIsControl`

A `SoftRow` is **one semantics node**: it composes the label and excludes
everything beneath it, so a worklist is one utterance per row rather than
four. That exclusion is also how a screen-reader user loses a button — a
`TorchTertiaryButton` dropped into `meta` paints, hit-tests and is announced
nowhere. The worklists shipped that way, and a semantics dump found zero
nodes for "Close with photo", "Verify" or the alert rules toggle.

So a row's verbs have two declared homes, and `meta` is neither:

```dart
SoftRow(
  title: task.title,
  subtitle: task.outletName,
  meta: Text('${task.slaPhrase} · ${task.requiredFix}'),   // words only
  // Ghost buttons beneath the text column, inset to it. They keep their own
  // nodes, and a `Wrap` stacks them at 2.0× by itself.
  actions: Wrap(spacing: TiqSpace.s4, children: <Widget>[
    TorchTertiaryButton(label: 'Close with photo', onPressed: _close),
  ]),
)

SoftRow(
  title: rule.name,
  trailingIsControl: true,     // this trailing is operated, not read
  trailing: TorchIconButton(
    icon: Icons.notifications_active_outlined,
    toggledOn: rule.active,
    stateWord: 'On',
    semanticLabel: 'Turn ${rule.name} off',
    onPressed: () => _setActive(!rule.active),
  ),
)
```

A plain `trailing` — a figure, a state word, a chevron — stays excluded,
because the row's own label already says it. And the row's `onTap` is a real
`Semantics.onTap`: a `GestureDetector` under an excluding node carries no tap
action, so `button: true` alone gives a node a reader can focus and cannot
activate.

**`enabled: false` is not a way to grey a row.** It means the control is dead,
and it makes `onTap` unreachable. A row that is *off* but still editable — an
inactive alert rule — carries the word, not the flag.

The rule's **colour is not a parameter**: `edgeStructure` (3.73:1) between
tappable rows because 1.4.11 wants a perceivable boundary around a UI
component, `hairline` between non-tappable ones because there it is decoration.
`SoftRowSeparator` therefore has two members — `auto` and `none` — and `none`
means "last in the group", not "a different line".

### The four configurations

Each is a *configuration* of `SoftRow` — a density, a mark, a severity and some
strings — not a second row. None of them paints a fill, an edge, a rule or a
radius of its own.

```dart
OutboxRow(                                // #382
  state: OutboxState.retrying,            // queued / sending / retrying /
  title: l10n.outboxShelfPhoto(outlet),   //   sent / stuck / waitingForVisit
  stateWord: l10n.outboxRetrying,
  sentence: l10n.outboxRetryingAt(nextAttempt),   // the REAL next-attempt time
  ageLine: l10n.outboxQueuedAt(item.queuedAt),
  payloadBytes: item.payloadBytes,        // DECODED bytes, from the sync queue
  stuckLabel: l10n.severityNeedsYou,      // required for `stuck`
  onTap: () => showOutboxItemSheet(context, item),
)

HeldWorkRow(state: HeldWorkState.held, ...)   // #391, the console's mirror
DecisionRow(title: ..., reason: ..., value: 71, unit: TiqUnit.percent,
            sparkline: Sparkline(...))        // the sparkline is a slot
PersonRow(name: ..., role: ..., outlet: ...)  // #399/#400 — never an id
```

### What is fixed, and why

| Rule | Where it lives |
|---|---|
| 56 / 64 / 80, collapsing to 64 in Veld | `SoftRowSpec.minHeight` |
| content starts at the same inset with or without a severity bar | `SoftRowSpec.severityLane`, always reserved |
| pressed = `lifted` fill **and** a 2px `edgeControl` rule **and** scale 0.98 **and** the tick haptic | `SoftRowSpec.resolve(pressed: true)` |
| critical = solid bar, watch = outlined bar, both plus a word | `SoftRowSpec.barFill` / `barStroke` + `severityLabel` |
| the trailing column drops beneath the text rather than squeezing the title | measured in `_RenderSoftRowContent`, never guessed from the text scale |
| a name middle-truncates; the full name is what a screen reader gets | `MiddleTruncatedText` + the row's `Semantics` label |
| **no amber, ever** | `row_amber_test.dart` — a pixel census with a budget of zero |

The press needs both channels because the fill step alone is 1.49:1 on the
Night well: invisible on a 6-bit panel at 40% backlight, which is the panel a
field agent has. On Day and Veld `lifted` is an ink block on paper, so the press
inverts and the ink goes to `ground` with it.

### Adopting it on a screen

1. Delete the `ListTile`, `Card` or `GlassPane` the list was built from. A row
   takes **no `Material` ancestor** — no ripple, no elevation, no `InkWell`.
2. Pass the whole row's tap as `onTap`. A thumb in a shop aims at the row, not
   at a 40dp trailing button.
3. Localise the words. Every string a configuration needs is a parameter:
   `stateWord`, `sentence`, `severityLabel`, `unknownLabel`. Nothing in this
   directory hardcodes English, and `severityLabel` is **required** whenever a
   severity bar is drawn — the bar is crimson, and the word is what survives
   greyscale, deuteranopia, glare and a screen reader.
4. Pass `separator: SoftRowSeparator.none` on the last row of each group.
5. Drop any per-row amber. If a row looks like it needs light, it has been
   misread: sending is Oatmeal dots, held is an Oatmeal square, live presence
   belongs to the route's one `TorchClaim.livePulse` and not to eleven rows.
6. Align anything you put *beside* a row — a section rule, a sticky header, a
   swipe background — to `SoftRowSpec.resolve(...).textInset(hasLeading: …)`
   rather than to a literal.

### The goldens

`test/core/widgets/torchlight/row/goldens/soft_row_<skin>.txt` — one line per
`form × density × severity × tappable × pressed × textScale`, per skin, in the
ruling's sequence: Night first, then Day, Veld last. They are **text**, not
PNGs: CI runs `flutter test` on `ubuntu-latest` while the repo is developed on
macOS, and an image golden that disagrees across platforms gets skipped within a
week. What unify §1.3 rules is a set of declared values, and a text golden names
the one that moved. The thing a PNG would catch — a row painting something
nobody declared — is caught by the amber census, which walks the real pixels for
the property that matters most.

Regenerate with `UPDATE_ROW_GOLDENS=1 flutter test`, and read the diff.

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

### 12.7 The trap that will cost you an afternoon: drift `watch()` and `pumpAndSettle`

Every agent screen carries the sync chip, and the sync chip watches the outbox.
Drift's `watch()` **reschedules a zero-duration timer on every tick**, so the
stream never goes quiet — and `pumpAndSettle` pumps until nothing is scheduled.
Against a real drift stream it therefore *never returns*. The test does not
fail; it hangs, with no output and no stack, until the file times out ten
minutes later. This cost several hours across two workstreams in one day, and
it is the same bug both times.

**The fix is a provider override, not a longer timeout.** Stub the derived
provider with a plain stream and let a repository test cover the real query:

```dart
// test/features/agent_harness.dart — in every agent screen test
syncStatusProvider.overrideWith((ref) => Stream<SyncStatus>.value(sync)),
visitProgressProvider.overrideWith((ref, arg) => Stream.value(progress)),
```

`agentBaseOverrides` does this for `syncStatusProvider`; `pumpVisit` does it for
`visitProgressProvider` and `visitReviewProvider`. `app_router_test`'s
`_appWithOverrides` does the same for both. If you add an agent screen that
watches the database, add its provider to that list before you write a test.

**The second half of it.** A test that is *about* the derivation — #389's
"a product list that will not load makes the section can't-confirm" — cannot
stub the provider away. Two more things then apply:

- Never call `pumpAndSettle` (nor `scrollUntilVisible`, which calls it on every
  step). Pump a fixed number of frames: `pumpVisitLive` and `dragAgentUp` do.
- **Unmount the tree yourself, and pump with a duration.** Cancelling a drift
  query stream schedules one last zero-duration timer
  (`StreamQueryStore.markAsClosed`). flutter_test unmounts the tree for you
  after the body and then calls `pump()` with *no* duration, which flushes
  microtasks but never elapses the fake clock — so the timer is still pending
  when `_verifyInvariants` runs and the test dies on *"A Timer is still pending
  even after the widget tree was disposed."* Worse, the next test in the file
  then hangs inside `db.close()`, waiting on a stream store that a dead
  `FakeAsync` will never drain — so one leaked timer presents as a hang two
  tests later. End such a test with `await disposeAgentScreen(tester)`.

---

## 13. Phase 1 — marks and figures

The things that carry state and the things that carry numbers. One import:

```dart
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
```

`lib/core/widgets/torchlight/mark/` holds the marks, `.../figure/` the figures.
**No screen is migrated by the PR that added them**; nothing in `lib/features`
changed. What follows is what a migrating screen has to know.

### 12.1 What replaces what

| New | Replaces |
|---|---|
| `StatusChip` | the status pills and `status_pill_colors.dart` |
| `FlagChip` | nothing — new (#393) |
| `SeverityMark` | ad-hoc coloured dots |
| `SectionStateGlyph` | `agent_state_glyph.dart` (#375) |
| `Delta` / `DeltaSlot` | `DeltaChip`, `DeltaPill`, `TileDelta.text` |
| `StatTile` / `StatCluster` | the `rich_figures.dart` tiles |
| `Meter` | nothing — new |
| `NotMeasured` | a zero with no explanation |
| `ProvisionalMarker`, `ReconciliationLine` | nothing — new (#377/#390/#398) |
| `Eyebrow` | `Text(label.toUpperCase())` |

The **person row is not here** — it belongs to the soft-row workstream.

### 12.2 Unknown versus zero — what each state looks like on screen

This is the heart of the work, so it is stated once, plainly, and every clause
has a test behind it.

| The data | The figure | The unit | The delta | The meter | The words |
|---|---|---|---|---|---|
| **A measured zero** | `0`, ink-1, full size, never suppressed | as normal | a **flat bar** (an 8×2 rectangle, not a triangle, not a dash) | no fill at all — a true zero draws nothing and the figure carries it | none needed |
| **A null** | an **em dash**, ink-3, at the figure's own role and face | **suppressed** — "— %" is a unit measuring nothing | **none, and no gap held open** | outlined empty track, **no target tick** | mandatory: "No visits in this window", or the server's cause |
| **Not measured** | an **em dash**, ink-3 | suppressed | none | a **full-width falling hatch** on the track | mandatory: "No competitor on shelf", or "Not measured in this visit" |
| **A low sample** | the real figure at **ink-2**, same role, same size | as normal | **removed**, replaced by "too few visits to compare" | the fill draws as a **1.5dp outline**, not a solid | "from 3 visits", or "small sample" where the count is unknown |
| **A thin baseline** | the real figure at **full ink-1** — it is a good figure | as normal | **removed**, replaced by "last week had too few visits — not compared" | normal fill | the same sentence |

Four rules that follow, and none of them is negotiable:

- **A tile is never hidden.** A cluster that silently drops a tile changes
  shape, and the reader cannot tell whether the metric was bad or missing.
- **A grey "Unknown" chip is never shown.** It is a claim that the system
  looked. Where a level has not been computed, no chip renders.
- **A delta never stands beside nothing.** `DeltaRule.resolve` returns
  `DeltaSuppression.nullFigure` and `DeltaSlot` renders a `SizedBox.shrink` —
  removed, not greyed, because a greyed delta is still a delta.
- **An absence always has a sentence.** `StatTile` asserts on a null value with
  no `noDataReason`; `Meter` asserts on a hatched track with no
  `reasonForHatch`.

### 12.3 The marks

```dart
StatusChip(level: StatusLevel.watch, detail: l10n.asAt('08:15'))
```

Five levels — `critical`, `watch`, `onTarget`, `held`, `live` — each binding a
hue, a silhouette and a word in one `StatusLevelToken`, so a level cannot be
given a colour without a shape and a label. Severity is **one hue at two
commitment levels**: outlined for Watch with a half-filled triangle, solid for
Critical with a filled one. `held` is Oatmeal `ink2` with a square, never
Truffle. Staleness is `detail` — a word — never an opacity: a 0.6 Watch chip
computes to 3.29:1 for 11px text and a contrast walk cannot see it.

```dart
FlagChip(kind: FlagKind.outOfFence, detail: '140 m', onTap: openTheMap)
```

Seven members: `outOfFence`, `forReview`, `unfinished`, `skipped`, `held`,
`noGps` — all six in **one neutral treatment**, legible in greyscale by
construction — plus `sentBack`, the only one carrying severity, because a human
rejected the work. Out of fence is a measurement, not a verdict. Every flag
chip should be tappable to its explanation; a flag the agent cannot interrogate
is an accusation. `cleared: true` steps the ink to `ink3` and appends the word.

```dart
SeverityMark(kind: SeverityMarkKind.watch)
```

Five drawn marks: `critical` (filled triangle, `badSolid`), `watch` (half-filled
triangle, `bad`), `onTarget` (filled circle, `good`), `held` (Oatmeal square)
and `notMeasured` — **a barred square, not a hatched one**. No pattern goes
inside a glyph. The word always renders beside the mark.

```dart
SectionStateGlyph(state: SectionState.cantConfirm)
```

Four states in a 28dp tile (48dp at 2.0×) holding a 16dp glyph (32dp at 2.0×):
a ring, a half disc, a tick disc, and **a ring with a 2px diagonal bar**.
"Can't confirm" is its own silhouette and not a hatch, because a 3dp stripe
inside a 28dp tile aliases to a flat grey disc at 40% backlight — which is
exactly what "in progress" looks like. `SectionStateToken.countsTowardReadiness`
is false for `cantConfirm`: the readiness denominator drops rather than the
numerator failing.

```dart
DeltaSlot(
  data: delta,                 // DeltaData? — direction and sentiment, both from the server
  figureState: tile.figureState,
  sampling: FigureSampling(kind: MetricKind.rate, n: 20, baselineN: 1),
)
```

The triangle is **drawn**, never typed: `TileDelta.text` built `▲`/`▼` as
characters, Onest does not carry U+25B2/U+25BC once `pyftsubset` has run, and
the PDF exporter rendered them as nothing (#401). `direction` is the shape and
comes from the wire's `direction`; `sentiment` is the colour and comes from the
wire's `sentiment`; neither is derived from the other, because a stock-out count
going up is bad and a spoilage count going down is good. The wire's `warn`
level maps to `neutral` — there is no amber warning in this system and a delta
is never a severity carrier. A null magnitude is "up from none" in words, never
`n/a` and never ∞.

### 12.4 The figures

```dart
StatCluster(
  tiles: [ StatTile(...), StatTile(...), StatTile(...) ],
  footer: heldChipAndSeeTheNumbers,
)
```

Four tiles maximum on a phone, three recommended, two in Veld. Cells are
separated by a **12dp gap with a 1px rule centred in it** — `edgeStructure` in
Night, the decorative hairline on paper, 2px in Veld. Both, not either: a
hairline alone measures 1.72:1 and a gap alone loses because a tile's own rows
are 8dp apart. Below 320dp of inner width (which is every phone) the cluster is
one column of horizontal tiles; above it, a two-column grid of vertical cells,
decided by `LayoutBuilder` and never by a text-scale guess.

`StatTile`'s phone layout is **horizontal**: eyebrow `Expanded` left, figure
right-aligned in a bounded box so `FigureSlot` can measure its candidate roles,
meter beneath, delta beneath. Variants: `lead: true` with a `severity` draws the
outline and a `subordinates` line; `provisional: true` adds the dotted rule and
the word; `reconciliation:` hangs a `ReconciliationLine` under the figure.

```dart
Meter(value: 61, target: 80, semanticsValue: '61 out of 100, target 80')
```

Track 4dp Console / 6dp Field / 8dp Veld, scaling at half rate. **The target
tick is ink-1 everywhere** and `TorchClaim.meterTick` does not exist: a target
is an annotation, an annotation is a label, and — the load-bearing half — the
amber budget is counted per *route*, where up to ten ticks can appear against a
budget of zero. The tick's silhouette (2dp wide, breaking the track's top edge
by 2dp) does the work the amber was there to do. `target: null` renders **no
tick**: never one at 100, never one at the midpoint.

```dart
NotMeasured(reason: 'No competitor on shelf')
ReconciliationLine(finalValue: 71, seenValue: 84, voice: ReconciliationVoice.console)
```

The reconciliation line has two string sets and shares none of them: the console
says "Scored 71 — the phone showed 84", the agent app "Now scored 71 — it was 84
when you saw it". Both figures set in mono at `figure.s`, so there are never two
competing large numbers. The direction triangle is hollow and **ink-3 in every
case** — never good or bad, because the arithmetic changed and the performance
did not — and nothing is struck through. The agent app never shows a provisional
score at all.

### 12.5 Sample thresholds

Declared once, in `sample_threshold.dart`, because "is three visits enough" is a
property of the metric and not of the screen: rates and percentages need n ≥ 5,
averages n ≥ 3, a score n ≥ 1 (a single visit's score is a fact about that
visit, not an estimate). Exactly at the threshold is the normal treatment — the
boundary is not a gradient. A **missing** `sampleSize` is not a low sample: the
client does not know, and inventing a number to compare against marks good
figures weak. Where the server says "thin" without saying how thin, pass
`FigureSampling.unknownAndThin` and the meta line reads "small sample".

`baselineSampleSize` is the field the low-sample rule originally missed.
Gauteng North loses week 37 to a strike, gets one visit at 100%, then twenty
visits at 84% in week 38: the figure is healthy, nothing about it is marked, and
the delta reads "−16 pts vs week 37" — a hard verdict computed against a single
visit, on which a manager reassigns an agent. On a load-shedding calendar this
is the common case.

### 12.6 No amber, and how that is enforced

Not one component in these two folders names a flame token or declares a
`TorchClaim`. `marks_amber_test.dart` renders **every state of every one of
them in all three skins** through the amber census and requires zero lit
regions, and then scans both folders for any spelling of an amber token. The
`Live` status chip is a `well` dot and the word; the breathing amber pulse that
can accompany presence is a separate emitter on the ladder, claimed by whatever
owns the presence, and is not part of this component.

### 12.7 Goldens

There are no `matchesGoldenFile` PNGs here, deliberately and for the same reason
the amber census has none: a byte golden fails on a font hint, passes on a
semantic regression, and gets re-baselined by whoever is in a hurry. The
goldens are **measurements**, Night first, then Day, Veld last:

- `section_state_glyph_test.dart` renders each of the four states, converts to
  luminance and requires that every pair differ — so "can't confirm" is proved
  distinguishable from "in progress" **with the hue removed**, which is the
  test a hatched fourth state would have failed;
- `chips_test.dart` does the same for the six neutral flag silhouettes, which
  have no colour difference between them at all;
- `marks_amber_test.dart` counts lit pixels;
- the per-state widget tests prove the words are on the screen.

`mark_harness.dart` holds `paintMark`, `greyscaleDifference` and
`inkedFraction`. The last one exists so a silhouette test cannot pass by
comparing two blank frames.

---

## 14. Phase 1 — the plate, the section rule, and The Floor

The first screen migrated to Torchlight, and the two components it needed that
nobody else owned.

### 14.1 What replaces what

| New | Replaces | Amber |
|---|---|---|
| `TiqPlate` + `PlateSpec` + `PlateFallback` | *(new)* | `TorchClaim.plateStripLight`, rung 2 |
| `SectionRule` (+ `SectionRuleAction`) | uppercase eyebrows used as section markers | none, ever |
| `Sparkline` + `SparklinePainter` | `charts.dart`'s pre-Torchlight `Sparkline` on Torchlight surfaces | none |
| `TheFloorScreen` + `FirstRunBoard` | `DashboardShellScreen` as the manager **home** | two, counted |

`DashboardShellScreen` is **not** deleted. The Floor replaces its KPI header and
its three needs-attention counters; it does not replace the trend, benchmark,
agent-activity or sales-attainment panels, which are separate spec items and not
yet migrated. Deleting the route would delete those features, so it moved to
`/dashboard/overview` with a nav destination of its own. `GlassPane` likewise
stays: it still has 101 call sites across `lib/`, and unify §5 is explicit that
it goes when its call sites are empty, not first.

### 14.2 The plate

**The fold is arithmetic.** `PlateSpec.heightFor(vh)` is
`min(clamp(0.44 × vh, 200, 360), vh − 440)` and nothing else. The second term is
the one that bites on a phone: at 360×640 it yields exactly 200, leaving 440dp
for the list. Under the 200dp floor the plate does not render at all and a 96dp
hero band replaces it — a smaller photograph is a photograph nobody can read
*and* a list nobody can use.

| viewport | height | strip light y | zone top | hero face |
|---|---|---|---|---|
| 640 | 200 | 76 | 84 | `hero.figure.compact` |
| 720 | 280 | 106.4 | 134.4 | `hero.figure` |
| 892 | 360 | 136.8 | 172.8 | `hero.figure` |
| 600 | *collapsed, 96* | — | — | `hero.figure.compact` |
| any, Veld | *none* | — | — | — |

**The light is one object.** A 2px `flame600` line at `0.38h`, clamped out of the
lower 40%, with a 48dp `glowAmber` gradient above it. Line plus bloom is one
light because that is what it looks like, and the pixel census counts it as one.
Two things gate it: `TorchScope.lit(...)`, and whether there is a photograph at
all. The second is not an optimisation — a light needs something to be a light
*on*, and a lit drawing is a decoration wearing the screen's one grant. A plate
with no photo therefore renders **zero** amber even holding the grant.

**The text-safe zone is a hard box.** A bottom-up scrim (`ground` 0% → 80%) over
the lower 52%, or 58% under 240dp. The provenance caption sits on its first line
and the hero cluster at its foot. When the cluster wants more room than the zone
has — which it does at the 200dp floor — the answer is the hero's own fitting
ladder (`hero.figure` → `hero.figure.compact` → `BoxFit.scaleDown`), **not** a
scrim that quietly grows to swallow more of the photograph.

**Provenance is mandatory.** A figure printed over a photograph of one named
store is read as being about that store. The `meta`/`ink3` caption at the top of
the zone — `Kasi Corner Spaza · 17 Sep 06:40` — is what makes the image visibly a
specimen and the hero cluster visibly about the territory. An uncaptioned plate
is the one state this component may not have.

**The bake is still owed.** The spec calls for a server-baked asset: 12% chroma,
no pixel above `plateCeiling` #474747, an alpha edge dissolve, ≤60 kB WebP. That
does not exist yet. Until it does the plate reads the existing ≤60 kB thumbnail
route and applies the *luminance* half of the bake client-side, as a `multiply`
blend on the image's own paint — one paint parameter, no `ColorFiltered` and so
no `saveLayer`. The chroma reduction, the dissolve and the byte cap stay on the
server, because a client cannot fix a 900 kB download by dimming it.

**Cost.** One `Image` decoded at `cacheWidth`; two gradient decorations (scrim,
bloom). Zero `BackdropFilter`, `ShaderMask`, `ImageFiltered`, `saveLayer` and
`BoxShadow`.

### 14.3 The section rule

A rule gutter to gutter with the section's name sitting on it, left, knocked out
12dp either side (16 in Veld), `title.m` 16/600 `ink1`, **sentence case**. A count
follows the name in `figure.s` tabular mono `ink3`, inside the same knock-out.
An optional ghost action sits at the far end in a 44dp box.

The rule is `hairline` in Night (2.14:1 — visible on a dark ground, and the text
carries the meaning) and `edgeStructure` in Day (3.41:1), because Day's hairline
at 1.18:1 is nothing and this is the console's only full-width line.

At 2.0× the name wraps and the rule **drops beneath** the text block rather than
running through it — a rule crossing two lines of type is a strike-through. The
decision is measured with a `TextPainter`, not guessed from a scale threshold.

An empty section still renders its rule and its name, followed by one `body`
`ink2` line. A section that vanishes when empty makes a manager think the
feature is gone.

**Amber: none, ever.** It replaced an amber section marker and a numbered
eyebrow precisely so it could not become a repeated accent.

### 14.4 The sparkline

A 64×20 shape, not a chart: no axis, no gridline, no label, no tooltip. It
caches to a `ui.Picture` inside a `RepaintBoundary` and carries the recording
across a rebuild when the series has not changed, because five of these
re-recording on every scroll frame is the budget gone.

Three rules it does not bend: fewer than two points draws **nothing** (a single
reading drawn as a flat line is a fabricated trend); a flat series draws through
the middle, not along the floor (no change is a horizontal line, not a zero);
and the last dot takes the row's **severity** ink, which is crimson at two
commitment levels and never amber — five rows of amber last-dots is the exact
repeated fill the law bans by name.

### 14.5 The Floor, and unknown versus zero

Top to bottom: the plate; the one dominant metric (on-shelf availability) as a
`StatTile(lead: true)` with coverage and the visit count as its subordinates;
the knocked-out rule `Needs a decision N`; up to five `DecisionRow`s worst
first; and `and N more need a decision`. Then the floating nav pill and its
circle. No cards, no shadows, nothing centred.

Three phases, and the screen never guesses between them from a figure:

| phase | what says so | what renders |
|---|---|---|
| first run | `totals.outletsTotal == 0` | the `FirstRunBoard` — a different screen |
| window empty | outlets exist, `totals.visits == 0` | The Floor, em dashes, sentences, no deltas |
| measured | visits in the window | the real thing, zeros included |

A measured `0` renders `0` and keeps its place. An absence renders an em dash in
`ink3` with the unit suppressed and a sentence in words. `sampleSizes` from
`GET /dashboard` drives the thin-sample treatment; the **baseline** denominator
is the previous window's own `sampleSizes`, from the second request the console
already makes, so a thin baseline is a fact rather than an inference.

The decision list merges alerts and tasks — a manager does not think in terms of
which table a finding came from — ranked by severity and then by age. Both kinds
carry `createdAt`, so the trailing column means **one** thing on every row: how
long this has been broken. Mixing an alert's age with a task's SLA deadline
would put two measurements in one column and make it unreadable as a column.

### 14.6 The amber census

| route × skin | objects | which |
|---|---|---|
| Floor, Night, with a photo | **2** | nav active tab, plate strip light |
| Floor, Night, no photo | **1** | nav active tab |
| Floor, Day | **0** | no primary on this route |
| Floor, Veld | **0** | no plate, no amber |
| First-run board, Night | 1 | nav active tab |

The hero's delta is severity crimson, the sparkline's last dot is severity
crimson, the section rule has no colour, the filter chip does not exist here and
the nav circle is denied outright by the ladder — the plate took rung 2 and the
circle sits at rung 4.

### 14.7 What is not built yet, and why

* **The filter rail** (territory × window chips) — the filter chip is Phase 2.
* **`Today's field`** (agents on the map, held work, coverage progress) — needs
  the progress bar and the person row, both Phase 3.
* **A sparkline on a live row.** The component is built and tested, but there is
  no per-outlet series on the wire today (`/dashboard` answers one window,
  `/trends/*` answers the territory). `DecisionRow` omits the slot rather than
  inventing a shape, which is its own documented rule.
* **The skin cycle on this route.** On a tab root it belongs in the app header's
  single trailing slot, and The Floor has no header — the plate is the header.
  It belongs in the Menu destination when the Menu sheet ships.
* **The plate's `Dark frame` state**, which needs the mean luma the server bake
  computes.

---

## 15. Phase 2 — the containers, the states and the inputs

Three folders — `sheet/`, `state/`, `input/` — and one rule that runs through
all three: **none of these components emits light.** The amber lint's emitter
allowlist is still pinned at ten files and none of them is here; the census in
`phase2_amber_test.dart` walks every state of every component in all three
skins and counts flame-hued regions. The only lit objects it finds are the
three sheet commit actions the ruling put on the ladder, and those are
`TorchPrimaryButton` asking `TorchScope` exactly as it does everywhere else.

### 15.1 What replaces what

| | replaces | amber |
|---|---|---|
| `TorchSheet` / `showTorchSheet` | `showModalBottomSheet` styling, and **the dialog** | none from the container |
| `TorchSheetSwap` | a second sheet | none |
| `ProofBlock` | "you have unsaved work" | none |
| `DecisionSheet` | *(new — #374)* | its safe action's `primaryCommit` |
| `ConfirmSheet` | the console's ad-hoc confirms | none, categorically |
| `SkipReasonPicker` | *(new — #395)* | its commit's `primaryCommit` |
| `SessionEndedSheet` / `SessionHeldLine` | *(new — #380/#392)* | its sign-in's `primaryCommit` |
| `Skeleton` / `SkeletonLine` / `SkeletonShell` / `SkeletonRows` | `CircularProgressIndicator` | none |
| `EmptyState` / `EmptyStateDrawing` | a centred "No data" | none |
| `ErrorState` / `TorchErrorMessage` / `TorchErrorRegion` | raw error text | none |
| `OfflineHeldBanner` | the ad-hoc sync banners | none |
| `TorchProgressBar` | *(new — #391/#396)* | none |
| `TorchToast` / `showTorchToast` | `SnackBar` | none |
| `PaginationFooter` | *(new)* | none |
| `TorchTextField` | `TextField` decoration | none |
| `TorchNumericField` | *(new)* | none |
| `CountStepper` | the current stepper | none |
| `TorchToggle` | `Switch` | none |
| `TorchCheckbox` / `TorchCheckboxGroup` | `Checkbox` | none |
| `ChoiceRow` | *(new)* | none |
| `TorchFilterChip` / `TorchFilterRail` | `ChoiceChip` | none |
| `TorchHandednessScope` | *(new — #407)* | none |
| `VerdictControl` | *(new — #392)* — the fraud queue's ruling | its commit |

`SectionRule` is **not** in this list. It landed in Phase 1 and already
generalises — count slot, action slot, empty line, the 2.0× wrap and the Veld
above-the-rule form. Phase 2 adds nothing to it.

### 15.2 The one modal container, and the dialog that is gone

Unify §1.7 deletes the dialog outright. A non-dismissible bottom sheet covers
every blocking case a dialog covered, and two modal containers is two sets of
insets, two dismissal rules, two scrims, and two answers to the question of
what happens to the amber underneath.

`TorchSheetSpec` resolves it once:

| | Night / Day | Veld |
|---|---|---|
| form | a sheet over a scrim | a **full-screen white route** |
| scrim | `ground` @ 72% | none |
| radius | 14, top two corners | 0 |
| outline | 1px `edgeStructure`, top and sides | 2px, all four |
| ceiling | 88% of the viewport | the route |
| grabber | `#616465`, 40×4, declared | none — a 56dp Close row instead |
| padding | gutter each side, 16 below the grabber, 24 + safe area at the foot | the same, at Veld's 24dp gutter |

Four rules carry the weight:

**72%, not 88%.** #380 requires the held work to stay *visible* behind the
session-ended sheet. The assistant surface's 88% defeats that, and its real
finding — that a sheet should own the screen — is honoured a different way.

**Every amber beneath a sheet goes out.** `TorchSheets.openCount` is a global
`ValueListenable` and `TorchSheetAware` is the one-line way a shell reads it
into `TorchScope(beneathSheet: …)`. The nav's active tab drops to its ink form
and the plate's strip light goes off, so the sheet's own scope genuinely owns
the frame without a heavier scrim hiding the thing the sheet is about. It is a
global and not an `InheritedWidget` because the widget that has to react sits
*above* the sheet's route and *below* the navigator that owns it, where nothing
the sheet publishes is visible.

**No stacking.** `showTorchSheet` asserts in debug on a second sheet and opens
anyway in release — a design rule must never drop a user's action on the floor.
A sheet that needs a sheet cross-fades its own content through
`TorchSheetSwap`, which under reduce-motion is not a zero-duration animation
but no animator at all: `AnimatedSize` at zero duration still re-dirties itself
inside its own `performLayout` when a pane arrives at a new height.

**The grabber is a hex.** `#616465`, in all three skins, measured — not "ink-1
at 38%", which is a different grey on every surface it lands on. Opacity is
banned as a colour channel for the same reason it is banned as a state channel.

### 15.3 The decision sheet, and the three sheets that are one shape

`ProofBlock` is the argument. A decision about invisible work is a guess: "six
sections and three photos" is a number and "unsaved work" is a feeling. It is
also what replaced the session-ended screen's old trick of rendering the live
screen behind itself at 0.35 opacity — which measured **2.84:1**, below 3:1
even for large text, and was a full-screen `Opacity` over a live widget tree,
meaning a full-screen `saveLayer`: the most expensive frame in the app, spent
making its own reassurance illegible.

`DecisionSheet` is evidence, then two unequal actions:

* the safe action on top, in the thumb's easiest reach — `Carry on from 11:04`,
  with the time in the label because the time is the evidence;
* the destructive one below it, with its cost in words (`Loses 6 sections and
  3 photos`), never "this cannot be undone";
* a tertiary `Not now` at the bottom, because **the bottom-most control under a
  travelling thumb is never the one that destroys something**.

Pressing `Start over` cross-fades *this sheet's own content* to a second pane
naming the consequence. Two taps and a named cost — no second modal, no typed
confirmation (too much friction in a shop), and no undo toast afterwards: the
two-step is the guard, and an undo that follows a guard teaches people to
ignore the guard.

A check-in older than twelve hours demotes `Carry on` to a ghost and promotes
`Check in again`, because a geofence fix from yesterday is not evidence of
being here now. The captured work is preserved and re-attached either way.

`ConfirmSheet` is the console's instance of the same anatomy, and it obeys the
same rule from the other side: with only two controls, `Cancel` takes the
bottom and the destructive commit sits above it.

`SkipReasonPicker` (#395) carries each reason **with its consequence** — "The
store would not let me" → "The manager is told the store refused" — in the
layout *and* in the semantics node, because an agent who knows a repair task
will be raised picks differently from one who does not. `Something else`
requires its note: "other" with no text is the hole the component exists to
close. Dismissal is always safe.

`SessionEndedSheet` (#380/#392) is **a state, not an error**: no triangle, no
crimson, no "error", announced politely rather than as an alert. A token
expiring at 14:00 on a Tuesday is a fact about a clock. After `Not now`,
`SessionHeldLine` — 44dp, a square, a count and a way back in — sits under
every header until it is resolved.

### 15.4 The states

**Skeleton.** Night's text-line blocks are `edgeStructure` (3.33:1 on the well,
3.73:1 on the ground), **not** `well`, which on the Night ground is 1.12:1 —
exactly the ratio the device floor forbids. Rows and panels are their own 1px
outline at their real geometry, empty. Nothing renders before 600ms; the
travelling rule is 2px **Oatmeal** on a 1400ms loop, never amber, because a
skeleton is loading and not live; after 10s the rule stops and a line appears.
**Veld has no skeleton at all** — the word `Loading`, at the gutter, and
nothing else.

**Empty state.** Left-aligned and top-anchored, never centred: a centred block
grows in both directions and at 2.0× with a four-line Afrikaans headline it
pushes its own action off the bottom at exactly the setting that needed it
most. Whole-screen gets a 64dp drawing from a **closed enum of three** — shelf,
pin, envelope — plus a display headline under the line-count fitting rule (1–2
lines 40, 3 lines 32, 4+ 26, floor 26). In-panel and inline get **no drawing**.

The three drawings are commissioned under **#404** and do not exist yet.
`EmptyStateDrawing` ships a placeholder behind the same API: a crude
single-stroke schematic inside a **dashed frame**. The dashed frame is the
signal — no commissioned drawing in this system will ever sit inside one, so a
dashed box on a screen means artwork pending and nothing else. #404 replaces
`state/empty_drawing.dart` and no call site: the API is the enum. **A stock
illustration is never imported**, which is the whole reason the enum is closed.

**Error state.** `TorchErrorMessage` is a closed set of six kinds and the
sentence each one gets, and `sanitise` deliberately ignores the exception's own
`toString` — a message that is sometimes an exception is a message that will
one day carry a host name, a file path or a token into a screenshot in a
WhatsApp group. The body **names the work's safety first**. A Retry appears
only where retrying is honest: never on no signal (theatre), never on an
unchanged rejection (it fails identically), never on a 403. `TorchErrorRegion`
asserts **one Retry per region** in debug.

**Offline / held banner.** Held is **Oatmeal plus a square plus a word** (§1.13)
— never crimson, and never Truffle either, because Truffle is the comparison
series and giving it a second meaning is the failure the severity system
avoids. Working offline is the normal state of South African field work: towers
go down with the grid and "12 held" is a normal Tuesday. `needsYou` is the only
state that raises a colour. Every state is the same height so content beneath
never jumps, and the **count is the semantics node's `value`, never its live
label** — in the live label it interrupted an agent mid-capture twelve times a
visit, during the one workflow where an interruption loses data.

**Progress bar** (#391/#396). 8dp track (12 at 2.0× — a graphic scales at half
rate), `lifted` fill with a 1px `edgeStructure` outline because `lifted` on
`ground` is 1.67:1 and a track you cannot see cannot state a proportion,
`chartNeutral` fill, ink-1 milestone ticks, and the reward notch breaking the
track's top edge by 3dp so it has a silhouette. **The fraction is always text**:
the bar is never the only statement of progress, and `0/9` renders rather than
hiding. Reaching the reward turns the fill `good` and fills the notch; nothing
pulses and nothing celebrates in colour. The near-reward amber exception was
written, argued and deleted — this is the most motivating object an agent sees
and therefore the most tempting thing in the product to light.

**Toast.** Four kinds, four silhouettes, floating above the nav pill (its
height plus a 20dp standoff plus the safe area) so it never covers the thing a
thumb is reaching for. A second toast replaces the first rather than stacking.
Held is a **fact**, not a failure: "Held on this phone · sends itself" takes
the neutral treatment and an Oatmeal square.

**Pagination footer.** "Showing the 20 riskiest of 74." There is no "Load
more" — the API serves a first page and a button that cannot deliver is
dishonest chrome. The unscored note (#236) is not optional where it is true: an
unscored visit is not a clean one, and a short list of the riskiest twenty must
never read as "nothing suspicious".

### 15.5 The inputs — the trough grammar

**Radius 10 at the bottom corners, 0 at the top.** A trough holds at the
bottom, and the shape says so before a word is read. `TroughSpec` resolves the
whole grammar once; `TroughRulePainter` draws the bottom rule as a straight run
between the two bottom corner arcs, because a `BoxDecoration` refuses a radius
on a border whose sides differ in colour and the rule differs from the outline
in exactly the states that matter.

A trough carries a **real edge on all four sides** at `edgeControl`: Night's
`well` on Night's `ground` is 1.12:1, and a field identified by that fill and
one bottom rule is a floating line on black. Focus **thickens** the rule
1px → 2px (2 → 4 in Veld) as well as changing its hue, which is the channel a
reader who cannot separate two greys still gets. Read-only drops the fill, the
edge and the rule entirely — it stops looking like a field, rather than being
dimmed to 0.8, which is a state the contrast walk cannot see.

> **The focused rule is ink-1 here, not flame-700.** Unify §1.1 keeps an amber
> focus rule and counts it against the route's budget; this PR ships none,
> because no Phase 2 component emits light and the emitter allowlist is pinned
> at ten files. The accessibility requirement the ruling itself states — *"2px
> minimum and never colour-only — the rule thickens 1px→2px"* — is met. The
> amber form is one token in one place when it lands: a `focusClaimId` on the
> field, an allowlist entry, and a `TorchClaim.textFieldFocus` declared by the
> route. Nothing else moves.

**Numeric field.** Mono `figure.m`, tabular, right-aligned so a column of
prices aligns on its decimal — until it does not fit, and then the **leading**
digits are anchored and the trailing ones scroll out under a 12dp fade, with
the full value rendered beneath while the field holds focus. Right-aligned, the
old field showed `4 567,89` of `R 1 234 567,89` in a 92dp trough and a manager
read it back and confirmed a wrong number. The locale decides the decimal
separator, and `1.5` typed on an Afrikaans phone is **accepted** and normalised
rather than refused.

**Count stepper** (unify §1.8, #407). The value trough leads and an adjacent
`[−][+]` pair sits at the trailing edge, 56×56 each (64 in Veld) with a 1px
rule between — the arrangement of every till and fuel pump in the country.
`[−]` and `[+]` at opposite margins is 250dp of grip-shift per adjustment,
twelve times a bay, for someone with a crate on their other arm.
`TorchHandednessScope` mirrors the whole control once; it defaults to
right-handed and **nothing infers handedness from where a thumb lands**. Below a
measured 120dp of trough the pair drops beneath as two halves — still adjacent,
still one thumb.

Three rules there are about data rather than layout:

* **typing opens a sheet** with `Cancel` and `Set`, so a stray tap can never
  replace a count with one digit;
* **`null → minus` records 0 and `null → plus` records 1** — landing on zero by
  accident silently raises a task for a manager, so it is never the accident;
* **zero is a finding and the whole control takes it** — the finding wash, a
  2px `bad` outline, the figure in `bad`, a status chip beneath, and
  `TorchBuzz.finding`, because the agent is looking at the shelf and zero is
  the most valuable thing they can record.

**Toggle.** 52×32 (64×36 Veld), a 26dp thumb with a **tick drawn inside it**,
and **the state word is mandatory** — it has a default rather than being
nullable, so a caller can localise it but cannot remove it. There is no
indeterminate state: a toggle sitting at off is a recorded *no*, and an
unknown binary is a `ChoiceRow` with nothing selected.

**Checkbox.** 28dp at 1.0×, **48 at 2.0×** — a meaning-bearing glyph scales
with the text and 48 is also the target floor. No mixed state. A required group
that was submitted empty takes the error on the **group**, not on the boxes: no
single box is wrong, and turning eight of them crimson says eight things are
broken.

**Choice row.** Two to four options, radius 6 — the chip material, so there is
**one** selected vocabulary across chips and choices: `lifted` fill, a 1px
ink-1 border, a mark, weight 700. Three channels, never amber.
**Nothing-selected is a state**, and it says so in words; re-tapping a selected
option does not deselect it, because an accidental deselect in a shop loses a
fact silently. The collapse to a column is measured on real width — and Veld is
always a column, whatever the arithmetic says.

**Filter chip and rail.** Selected is lifted + a 1px ink-1 border + a tick +
weight 700, and **never amber, on any screen, in any skin**: a rail is a row of
chips, a multi-select rail is three or four selected ones, and four amber edges
in one horizontal scroller is the repeated-fill violation the amber law exists
to prevent. A disabled filter stays visible with its count at zero — hiding a
filter because it is empty hides the fact that it is empty. In Veld the rail
does not scroll: horizontal-scroll discovery fails outdoors.

### 15.6 The guards

* **`phase2_amber_test.dart`** — the pixel census over every state of every
  component × three skins, plus a source scan proving no file in the three
  folders names a flame token, plus a check that none of them is on the emitter
  allowlist. It checks `takeException` *before* it counts: an `ErrorWidget` is
  crimson, so a component that failed to build would otherwise pass a test
  proving a red screen contains no amber.
* **`phase2_scale_test.dart`** — every case at 2.0× and in Afrikaans, at 320dp
  and 360dp, asserting nothing overflows. The height is generous because a
  block taller than a phone at 2.0× is a paragraph and every real screen
  scrolls; **the width is the instrument**, and what it catches is a pin.
* **`phase2_golden_test.dart`** — text goldens of every resolved
  `TorchSheetSpec` and `TroughSpec`, one file per skin, Night first and Veld
  last. Regenerate with `UPDATE_PHASE2_GOLDENS=1`.
* **`sheet_test.dart`, `state_test.dart`, `input_test.dart`** — a test per
  state.

### 15.7 What is not built yet, and why

* **The three empty-state drawings** (#404). The placeholder is deliberately
  obvious; see §15.4.
* **The amber text-field focus rule.** Argued above; one token, one allowlist
  entry, one claim when it lands.
* **`Menu sheet`** — on the canonical list, still waiting on a screen that
  needs the grouped-with-counts form; the console's overflow ships as the
  plain rows-and-rules version in `console_frame.dart`.
* ~~**`Verdict control`**~~ — **landed with the fraud review queue.** Three
  stacked rows and a commit, in `input/verdict_control.dart`. It stacks
  whatever the measurement says (`ChoiceRow.forceColumn`, added for it):
  one of its options accuses a person of faking their work, a verdict is
  INSERT-ONLY against a unique `visit_id`, and three 44dp targets side by side
  on a 360dp phone is a mis-tap that cannot be taken back. Nothing is
  pre-selected — a control that defaulted to "cleared" would record a decision
  nobody made every time somebody opened the sheet and closed it. A ruling that
  demands a note cannot be committed without one, and the primary's
  `blockedReason` names what is missing rather than leaving a dead button.
* **The sync status *chip*.** The banner form is built; the chip is a Phase 1
  header component and the two are one component in two forms (§1.14).
* **Toast queue collapsing** ("3 captures held" from three toasts in two
  seconds). The replace-don't-stack rule is implemented; the counted collapse
  needs the outbox's own event stream.

---

## 16. Closing a visit — the gate, the outcome, and capture

The three screens an agent meets on their way out of the shop, and the one
component that had to change to make the third honest.

### 16.1 What replaces what

| New | Replaces | Amber |
|---|---|---|
| `SubmitGateScreen` on `VisitFrame` | the `AgentScaffold` gate, its `PanelCard` task list and the glass checklist | one — the primary, in every phase |
| `VisitOutcomeScreen` on `VisitFrame` | the washed hero, `ScoreBandBar`, `BenchmarkBar`, the local `_HatchPainter` | one — `Next store`, in every phase |
| `GuidedCaptureScreen` on `TorchShell` | the `Scaffold` + `AppBar` launch wrapper | one — `Open camera`, then `Use it` |
| `photo_exposure.dart` (`meanLuma`, `photoExposureProvider`) | a dark photo kept or dropped in silence | none |
| `seen_score.dart` (`seenScoresProvider`) | *(new)* — the reconciliation line's referent | none |

The score's own hero is `FigureSlot` at `hero.figure` with `hero.figure.compact`
and `display` behind it, the band is a `SeverityMark` plus the word, the
dimension rows are `Meter` and `NotMeasured`, and the reconciliation line is the
component from §13. Nothing here draws a bar or formats a number itself.

### 16.2 The figure is never the severity

The hero is **ink-1 at every band**, including Gap. A severity-coded figure at
72px is a hue doing a number's job, and it is the one object on the screen large
enough that its colour reads as the whole message. The band is carried three
ways instead — a filled circle / half-filled triangle / filled triangle, the
word (Healthy · Watch · Gap, #408), and `good`/`bad` ink on the word — and all
three survive greyscale.

The meter's target tick is **ink-1 on all six rows**. The agent spec asked for
amber on the one dimension the band is about; unify §1.1 deleted
`TorchClaim.meterTick` and the ruling wins. Six ticks of the same class against
a budget of one is a repeated fill wearing a different hat, and the tick's
silhouette — 2dp wide, breaking the track's top edge — is what carries it.

### 16.3 A dark photo is a question, not a verdict

An aisle photographed with the lights off produces a frame nobody can read, and
the app has two dishonest answers available to it: keep it (a manager finds out
a week later) or drop it (the agent walks out believing they captured
something). So the returned bytes are measured — `meanLuma`, Rec. 601, decoded
at **16×16** because a 12 MP decode on the capture path is an OOM on a 2 GB
handset — and anything under 18% comes back to the review step edged in
`comparison` with "Dark — retake?" beneath it.

It is **never auto-rejected**. During Stage 6 it may be the only obtainable
evidence, and the mark travels with the photo into the section body so the fact
is not forgotten the moment the capture route pops.

A frame that will not decode measures **null**, and null is not dark. The app
does not accuse a capture it could not read.

> **`photoExposureProvider` is a test seam, and it is not optional.**
> `ui.instantiateImageCodec` resolves on the engine's own thread, which
> `FakeAsync`'s clock never reaches: a widget test that really decoded an image
> would hang in `pumpAndSettle` with no output — §12.7's drift-`watch()` trap in
> a different costume. Screen tests override the provider with a scripted luma;
> `photo_exposure_test.dart` measures the real thing inside `tester.runAsync`.
> **Every test that drives `PhotoCaptureField` or `GuidedCaptureScreen` must
> override it**, including the ones on manager screens.

### 16.4 The reconciliation line needs a referent, and the wire has none

"Now scored 71 — it was 84 when you saw it" needs to know what this phone
displayed the first time. The server knows what it scored, not what was on the
screen, so `seenScoresProvider` records the number the moment the outcome paints
it — in `flutter_secure_storage`, for the reasons the phone-only pin report
once gave (that report now goes to the server; #386): a drift migration for a
per-visit integer nobody queries is a schema version for a preference, and a
queued item for an endpoint that does not exist retries until it is `stuck`.

Two rules make it work rather than cancel itself out:

* **`record` never overwrites.** The first number the agent saw is the referent.
  Recording the second one would make the line read "now 71 — it was 71" once
  and then never appear again.
* **`record` awaits the read.** A write started on the first frame would
  otherwise land before the disk answered and erase the referent — the exact
  failure the component exists to prevent, caused by the component.

The screen takes no latch and keeps no copy: it reads the watched map every
build, and the no-overwrite rule is what keeps the line stable.

Two more things have to be true, or the line is a component nobody can be on
the right screen to read. It only ever appears on a **later** open — on the
first one, what the phone recorded is what the phone is showing — so:

* **`visitOutcomeProvider` is auto-dispose.** Kept alive it was fetched once
  per session, and a second open replayed the number from the walk out of the
  shop. Every open of a submitted visit's outcome asks the server again.
* **A submitted visit is re-openable from My work.** The outbox sheet for a
  sent `visit_submit` row carries a ghost "See how it scored" (never the
  amber: reading a score you have already been shown is not the expected next
  move), which resolves the draft's outlet from drift and goes to
  `/audit/:outletId/done`. `SyncItem.visitDraftId` decodes that row's payload
  so the sheet knows which visit it is looking at. The outlet's *name* comes
  from `outletsListProvider` only when it is already in memory — opening a
  score must not send a phone in a shop after an outlet list.

`outcome_reopen_test.dart` walks that route: submit, My work, the row, the
sheet, the score — and the line, once the server total has changed.

### 16.5 Can't confirm is something to raise

Every can't-confirm section gets its own row on the gate, named, with its reason
in words and "The manager is told · not confirmed" beneath it. The old gate
listed nothing for them, so a store that refused four counts produced a gate
printing "this store is in good shape" — which was the cleanest fraud path in
the app, and #389's other half.

### 16.6 What is not built yet, and why

* **The in-app camera (#405).** Out of scope by the brief. Capture is a framing
  card, the OS camera and a review step, and the screen does not pretend
  otherwise.
* **"Record this as a store I could not work."** The agent spec makes the gate's
  primary change identity when every required section is can't-confirm, writing
  a *skipped* visit — a different object to the server and to the fraud module.
  That is a new write path and a wire change, not an appearance change, so it is
  not built here. It is also currently unreachable: since #389 the hub blocks
  the submit while any required section is can't-confirm, so the gate cannot be
  opened in that state at all.
* **The held outcome's per-visit outbox rows.** The spec wants "the live outbox
  rows for THIS visit only". `SyncItem` carries no visit id — `visit_review.dart`
  gets there by decoding each row's payload — so the held screen carries the
  header's sync chip and the held banner instead of a per-visit list.
* **The reconciliation line's "Why?" sheet and its biggest-mover line.** Both
  need the *previous* dimension scores, and only the total is recorded.
* **`evidence_thumb.dart`.** It renders inside the manager's alerts and tasks
  screens, which are still Lumen, and its full-photo view is an `AlertDialog` —
  which unify §1.7 deletes in favour of a sheet. Both changes belong to the
  manager surface's migration: a Torchlight sheet opened from a Lumen worklist
  row is the "Torchlight frame around a Lumen form" this document already warns
  about, and moving it now would strand it between two systems.
