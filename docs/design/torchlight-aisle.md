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

## 9. Adding a token

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

## 10. Migration status

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
