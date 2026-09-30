# TradeIQ · Torchlight Aisle — One System

Five surfaces (kit, figures, agent, manager, assistant) reconciled against `refine-cinematic.json` and the owner's five standing decisions. Where the spec and an owner decision disagree, the owner decision wins (typeface: Onest + JetBrains Mono; nav: floating pill with a solid amber active tab and a separate circle). Where two designers disagree, one is picked below and the reason is one sentence.

---

> **OWNER OVERRIDE — 28 September 2026. VELD IS REMOVED FROM THE PRODUCT.**
>
> Veld was the third skin: white ground, near-black ink, radius 0, 2px
> borders, no gradient, shadow, rim, scrim or blur, nothing under 9:1 for a
> word or 15:1 for a border, 56dp targets, 64dp rows, larger declared type
> steps, the nav docked full-bleed, sheets becoming full-screen routes, and
> no plate, sparkline, chart, map or thumbnail at all. It existed for one
> reader: **a field agent reading this app in direct sunlight.**
>
> The owner was shown that trade and chose removal anyway. **What is given up
> is outdoor legibility for field agents.** An agent standing in a forecourt
> at 13:00 now reads the Day skin — Palladian paper, a 1px hairline grammar,
> radius 22 cards, `ink1` at 11.12:1 on the well — which is a legible screen
> in a car park and a compromised one in full sun on a 6-bit panel at 40%
> backlight. Nothing replaces it: there is no high-contrast mode, no
> outdoor trigger, and no solar-elevation entry.
>
> **The skin cycle keeps its place, its semantics label and its persistence
> and becomes a two-state toggle**: paper (Day) and moon (Night), cycling
> Day → Night → Day, 56dp in both. It is still on every screen, because the
> control that gets a person out of a skin they cannot read is still the one
> control no screen may be without.
>
> Every Veld clause below is struck through rather than deleted, so a reader
> who finds the old rule finds the decision beside it. The code carries none
> of it: `SkinMode.veld`, `TiqDensity.veld`, `TiqSkin.veld()`,
> `TiqPalette.veld`, `TiqSpace.veld`, `TiqType.veld`, `TiqDepth.veld`,
> `TiqRadii.flat`, `AppTheme.veld()`, `TiqSkin.textFloor`/`borderFloor` and
> `MotionBudget.veld` are all gone.
>
> **What Veld justified and what survives it.** `TableTwin` and its
> chart/table toggle stay: charts not rendering outdoors gave the twin a
> purpose, but it is also the screen-reader-reachable and printable
> equivalent of a drag-scrub plot, and that reason outlives the skin. The
> panels that *forced* the table in Veld now simply offer the toggle, which
> is what an indoor reader always had. `MarkShape`, the hatch kit, the
> severity word beside every severity hue and the list halves of the map
> panels are all likewise kept on their own merits.

---

## 1. Contradictions — rulings

### 1.1 The amber budget and how it is counted
| Surface | Said |
|---|---|
| Kit | TorchScope: 2 grants Night, 1 Day ~~/Veld~~; nav active tab is a *reserved chrome grant* in Night; content gets 1 grant on tabbed routes, 2 untabbed. Ladder: primary → plate → chart focus → nav circle → live pulse → meter tick. |
| Figures | AmberLedger: 2 per screen, chrome counted, resolved statically per phase; data-layer amber exactly once in the product. |
| Agent | Composed-frame lint: 2 Night, 1 Day ~~/Veld~~; nav pill is object #1 on tab roots; allows an amber target tick on Outcome, the reward bar and the stat tile. |
| Manager | TiqLedger: nav active slot **exempt**, one content nomination. |
| Assistant | 2 counted, nothing exempt; nav is a 3dp **underbar**; the pill **retracts on scroll**. |

**Ruling — Kit's TorchScope is the mechanism, Figures' static resolution is how it runs, and the arithmetic every surface actually lands on is the same:** Night = the nav's amber tab (when the nav renders) + one content object on a tabbed route; two content objects on an untabbed route (inside a visit, a sheet, a full-screen state); Day ~~/Veld~~ = one, the primary commit block. The nav is *counted* as slot 1 (manager's "exempt" and kit's "reserved" produce the same number; "counted" is the honest word). The claim set is computed by the route's view model at construction and per declared phase (figures), never per frame, so a grant can never blink. The assistant's underbar becomes the pill (owner decision 3); the assistant's scroll-retracting nav is rejected — kit and manager both forbid chrome that changes on scroll, and a slot that came and went with a thumb would make the count flicker.

**Meter target tick: ink-1 everywhere. `TorchClaim.meterTick` is deleted from the ladder.** Figures and manager win over kit and agent: a target is an annotation, an annotation is a label, and the tick's silhouette (breaking the track's top edge) is what carries it. Agent's Outcome drops to 1 amber (Next store), What I've earned to 0, the agent stat tile to 0.

**Live pulse means presence, never progress.** Kit gave the outbox row and the held banner a `livePulse` claim; agent said sending motion is Oatmeal dots. Agent wins: the pulse is reserved for a human mid-visit (person row, day trail), a tool executing (Ask), and a GPS fix being sought (check-in locating). Uploads are progress, and progress is a report.

**Text-field focus rule (2px flame-700) is counted, not exempt.** Kit exempted it; agent counted it; assistant cut it. Keep it and count it: it fits because the keyboard hides the nav (kit's own keyboard-open rule), returning that grant to content, so a focused field plus a lit primary is exactly two. The D-pad/keyboard focus ring stays exempt (it never co-occurs and never appears for touch users).

**Diverging chart axis is never amber** (assistant over figures/spec): a 1dp ink-1 axis at 15:1 is more visible than amber, and amber there would displace the focus row for no legibility gain.

**Data-layer amber is allowed wherever the ladder grants it, not "once in the product" (kit over figures):** the Territories list may light its worst bar; the dashboard cannot because the plate takes the grant. Figures' "exactly once" was a consequence of its ledger, not the law.

### 1.2 Navigation geometry
- **Bar:** radius 999, 64 tall, inset 16, 20 above safe area, `well` fully opaque, 1px edge-structure outline (kit). Agent/manager/assistant's radius-14 bars lose to owner decision 3.
- **Active tab:** solid flame-600 pill, radius 999, 48 tall, inset 6, ink `#0B1017` (kit). Day ~~/Veld~~: solid Abyssal block, ink Palladian ~~/white~~ — never amber.
- **Slots: four maximum** (kit's 360dp arithmetic). Manager: **Floor · Work · Ask · Menu**; Territories move into Menu under OPERATE. Agent: Today · My work · Map · Me.
- **Circle: 64dp**, outside the bar, 12dp gap (kit; manager's 56 loses because it is the primary action ~~and 56 is the Veld floor~~).
- **Skin cycle is not on the nav row.** Agent put a 56dp skin cycle beside the pill; at 360dp that leaves 192dp for four slots. Ruling: on tab roots the skin cycle is the app header's single trailing icon button (kit's header allows exactly one; assistant already put it there); on every other agent screen it sits at the leading end of the thumb zone (agent).
- **Large text:** the bar measures every localised label with a `TextPainter` and goes icon-only as a whole (kit). Agent's 76dp bar and 2×2 grid at ≥1.6× lose — a 132dp nav grid plus a circle plus a thumb zone is a third of a 640dp screen.
- ~~**Veld docks the nav** — full-bleed, 72dp, 2px top border, radius 0 (manager): a white pill floating on white under glare stops reading as a bar, and Veld has no radius but 0.~~ **Struck 28 September 2026** — the nav floats in both remaining skins.

### 1.3 Rows — separation, height, fill
| Surface | Row boundary in Night |
|---|---|
| Kit | 1px edge-structure outline on every row, radius 14, 8dp gaps |
| Agent | flush, radius 0, 1px rule inset to the text edge — edge-structure between tappable rows, hairline between non-tappable |
| Manager | no line, no radius, 12dp ground gap, optional hairline seam |
| Assistant | 20dp clear space + hairline-decorative |

> **OWNER OVERRIDE — 25 September 2026. The list-row half of this ruling is overturned.** The owner rejected the flush form twice against the running screens ("I hate this box style"; after #458, "it's still very boxy and I don't need that") and sent a reference with the instruction "this is the exact look I'm looking for, roundness — make it exactly as it is on this image." **A list row is a card:** radius 22 (`TiqRadii.card`), `surface` fill as a declared composited hex, **no outline**, an s5 margin so a bled list sits on the screen's gutter line, and an **s3 gap of ground** instead of a rule. The severity bar becomes an 8dp **dot** at the same lane. The press keeps two non-motion channels: the fill steps to `lifted` and the card *gains* a 1px edge-control edge. ~~**Veld is exempt and keeps the flush form below** — radius 0, no fill, 2px borders, the bar — because a soft translucent row on white under glare stops reading as a row.~~ **Struck 28 September 2026** — there is no exemption left, and every row in the product is a card. The anti-slop concern below is answered rather than dropped: cards are the grammar for **lists of things a person acts on** and for the one figure block beside them; nothing else gains a radius, and the device-floor argument still holds because a card is identified by its silhouette, not by its 1.49:1 fill. ~~Standalone rows are unchanged.~~ Full reasoning: `docs/design/torchlight-aisle.md` §9c.

> **OWNER OVERRIDE — 29 September 2026. "Standalone rows are unchanged" is struck.**
>
> > *"Now look at the manager side of the app. The agent side is looking completely off and not like the manager side. Please make them align and don't change the manager side, it looks perfect"* — and, looking again, *"The agent side is still rectangular."*
>
> The clause struck above was read correctly and implemented faithfully: `today_screen.dart`, `my_work_screen.dart`, `audit_shell_screen.dart` and `submit_gate_screen.dart` each cite §1.3 by number in a code comment, and each built a radius-14 `surface` block with a 1px `edgeStructure` outline for exactly the four objects this clause names — Next-up, the day block, the readiness block, the outbox summary. **This is not drift.** The manager side then moved its own figure blocks to `TorchCard` in practice (§9d, §9f) and nobody amended this sentence, so the two surfaces diverged by following two different rulings, one written and one shipped.
>
> The owner has settled which is the reference: the manager side. So —
>
> **A standalone block that holds a FIGURE is a card**: `TiqRadii.card`, a `surface` fill as a declared composited hex, **no outline**, and `TorchCard` is the component. The Next-up card, the day block, the readiness block, the outbox summary, the gate's captured block, the score hero, the too-far distance block and the wrong-pin evidence block are all instances. A severity on one of them is the **8dp dot** of the paragraph above, never a bar down its leading edge — the same correction §1.17 made to the overview's headline on 28 September.
>
> **What is NOT struck.** Two things keep the radius-14 outlined material, and neither is a figure block:
> * **A container that is not an object.** `TiqRadii`'s own distinction holds — a panel is a container and a card is an object. An instruction block (the photo framing card), a form's picker row (`SoftRowForm.standalone`, which every manager form uses), a sheet body and an input trough are containers and stay where they are.
> * **A skeleton.** §1.11 is explicit that a placeholder is "their real outline at their real geometry, empty", and the reason survives the override: a `surface` block on the Night ground is **1.49:1**, one quantisation level on a 6-bit panel at 40% backlight, so a filled card with no edge is a skeleton nobody can see. A skeleton for a card is still drawn at radius 14 with a 1px `edgeStructure` outline. This is the one place in the product where the placeholder deliberately does not have the arriving object's silhouette, and the device floor is why.
>
> Full reasoning and the per-use split: `docs/design/torchlight-aisle.md` §20.

> **OWNER OVERRIDE — 29 September 2026, later the same day. A STANDING STATEMENT is a card too, and the Today card's anatomy follows the mockup.**
>
> > *"Literally you didnt change anything"* — the owner, looking at Me, My work and Today after the round above shipped; and, re-sending the approved mockup, *"please focus"*.
>
> They were right about those three screens. The clause above moved every standalone block **that holds a figure**, which is what it says, and the block that opens all four agent screens holds no figure: the location banner — *"Your location is shared with your manager / Nothing is sent in the background"* — is a `SoftRowForm.standalone` at radius 14 with a 1px `edgeStructure` rim, and it is the **first object on the screen**, above a day block that has been a `TorchCard` since 26 September.
>
> **A standing statement under a header is a card**: `SoftRowForm.list`, radius 22, `surface`, no outline. Both location banners and the two consent panes behind them (`TorchCard`). The gutter moves with the material — a card-form row insets its own card by `margin: gutter`, so a shell whose children are already inset bleeds the banner out by `2 × gutter` for its edge to land on the same line the day block hangs off.
>
> **What is still NOT struck: a form's picker row.** `SoftRowForm.standalone` is unchanged on the nine manager screens that use it — client config, outlet detail, the sales import sheet, the dynamic template form, both report forms, templates, dispatch and the contest form. A row inside a form is a container the form owns, not a statement the screen is making.
>
> **Today's card anatomy, from the mockup rather than from the app's own history.** Three things, all composition rather than radius, because fixing corners inside the wrong layout does not answer the note:
> * **The figure leads its card.** The route card's `ROUTE` eyebrow is deleted — the mockup opens on `4` with "of 9 stores" on its baseline and no kick above it, on a screen whose header already says Today and whose date line already names the plan. The app's own extra sentence ("Distances are off — this phone will not say where it is") is **kept**, because it is a real state the mockup never had to show, but it moves off the figure's baseline onto its own line under the card's visual, at meta, ink-3: it is supporting text about why the rows below carry no distance, not a second reading of the count.
> * **A stop is a tile and a name on ONE row.** The Next-up card stacked a bare numeral, a `title.l` name, the code, then the button — a heading block. It is now the same anatomy as the rows beneath it: tile, then name at `title.m` (row scale) over `CODE · distance`, then the commit. The trailing lane on the rest-of-day rows loses the distance and the word "To do"; the ordinal tile and the row's position say it, and the words stay in the row's `semanticsLabel`.
> * **One tile object for every stop number.** See §1.5.

> **OWNER OVERRIDE — 29 September 2026, later again. A FIGURE BLOCK WITH NO BLOCK IS STILL A FIGURE BLOCK, and the reward bar is one.**
>
> > *"lets fix this section to match the style of the app"* — the owner, on the agent's Me screen, after the two rounds above had shipped.
>
> The first override moved every standalone block **that holds a figure** onto `TorchCard`, and the second moved the standing statements that hold none. Between them they missed a third case, which is what Me was made of: a figure block that had **never been given a container at all**, so there was nothing on the screen for either ruling to match against and neither round touched it. What I've earned drew a full-content-width progress bar and a two-cell `StatCluster` directly on the ground, above a ledger of cards — two grammars with the seam halfway down the screen, which is the exact complaint §1.3 has now been asked three times to answer.
>
> **The rule is about the figure, not about what the figure is already wearing.** A block that holds a figure is a card whether it arrived as a radius-14 outlined block, as a `StatCluster`, or as nothing at all. Me's two are instances: the **standing card** (points, with rank subordinate) and the **incentive card**.
>
> **A meter never spans the screen.** The progress-to-reward bar ran the full content width with nothing containing it, which made an unframed bright rule the loudest object on the screen — the last surviving instance of the *"lined, rectangular style"* the owner had removed from the Tasks lead card the same day, and the one thing on the agent side that touched both gutters. Inside a card it inherits the card's padding, and that is where the bleed goes. It is **not** deleted: the hub dropped its own meter in #486 because the track was a fourth drawing of a fraction the card already printed three times, and this bar is the opposite case — it is the only drawing of its fraction, and it carries the reward's name at the end of the track, which is the whole reason the component exists. `surface-agent.json` items 14 and 40 are amended to match.
>
> **Which grammar a goal-with-progress reuses.** The manager side has no exact twin, so rather than invent a fourth this takes the visit hub's progress card (#486) — itself the manager's Tasks lead card — and lets the bar occupy the figure slot. Three grammars in the product, not four.

**Ruling — one component, two forms.** **List rows** are flush, radius 0, separated by a 1px rule inset to the text edge: edge-structure (3.73:1) between tappable rows, hairline-decorative between non-tappable (agent). **Standalone rows** (Next-up, day block, readiness block, outbox summary) are radius 14, `surface` fill, 1px edge-structure outline (kit). Manager's gap-only rows fail the device floor (a 12dp gap between two 1.12:1 fills is the circular argument kit already killed); kit's outline-per-row in a list is the "uniform rounded cards" anti-slop failure and closer to a hard box than owner decision 2 allows. Manager's 3px severity bar and its "content starts at 35dp whether or not a bar is present" alignment rule survive.

**Heights — kit's three densities win:** compact 56 (Console lists), ~~standard 64 (Field lists)~~, tall 80 (two meta lines: Next-up, outbox, person, decision rows — manager's 76 rounds up). ~~Tappable targets are ≥48 everywhere; manager's 44dp tappable rows and assistant's 48 both map to compact 56.~~ **Both struck, 29 September 2026 — see §1.25.**

**Pressed row (Night):** fill → lifted **and** the row's rule/outline steps to 2px edge-control, plus scale 0.98 and `Buzz.tick`. (Under the 25 September override a card has no resting outline, so it *gains* a 1px edge-control edge instead of doubling one — the same two non-motion channels.) Manager's 3px leading tick at x=0 is rejected — it collides with the severity bar's position vocabulary ~~and Veld's 2px border~~ — but its complaint (lifted-on-well is 1.49:1) is answered by the edge step.

### 1.4 Stat tile
- **Phone layout is horizontal** (figures): eyebrow `Expanded` left, figure right-aligned, meter beneath, delta beneath. Single column below 320dp inner width — which is every phone. Assistant's 272dp threshold (2×2 at 138dp cells) loses on its own arithmetic: "R 1,28 mln" at JBM 32 is ~192dp.
- **Cell separation:** 12dp gap with a centred 1px edge-structure rule in Night, hairline in Day (assistant's tier-2). Figures/agent's hairline-only loses (1.72:1 is invisible); manager's no-line loses (the grid is the instrument reading). **Amended 29 September 2026 — the rule survives only where the cells are PEERS.** *"Let's remove this lined, rectangular style"*, and the Tasks lead card's three rules came out the same day; the clause above was written about an instrument panel and was being applied to a lead card's subordinates, which are not a grid and not an instrument reading. Two forms now, and the difference is whether one figure outranks the others: **peer cells in a `StatCluster` keep the gap and the rule** — eight manager and assistant call sites, plus the agent's own contests screen, all unchanged; **a lead card's subordinates are separated by the gap alone**, because two figures on one right edge already read as a pair and the alignment the rule advertised does not need advertising. `_LeadBlock` on Tasks, `_ReadinessBlock` on the visit hub (#486) and `_StandingCard` on Me are the three instances. The 1.72:1 objection stands and is not what this amends: a rule between peers is still a rule, and the reason it is not needed between a lead and its subordinate is rank, not contrast.
- **Eyebrow:** uppercase, 11/700, tracking **+4%**, wraps to 2 lines (manager). Applies to the eyebrow role globally.
- **`chart-neutral` moves to #A39887 Night / #5C5648 Day** (figures) — the old value sat at 3.01:1 and the Day value was byte-identical to ink-3. Kit, agent and manager update.
- **Count on phone:** 4 max, 3 recommended (figures).
- **Manager's "lead indicator"** is a StatTile variant (`lead: true`), not a component.

### 1.5 Section state glyph and "can't confirm"
- **Can't confirm is a fourth silhouette, not a hatch** (figures over kit, agent and manager): a ring at the empty ring's stroke with a 2px diagonal bar. A 3dp stripe inside a 28dp tile aliases to a flat grey disc at 40% backlight — the half-circle it must not resemble. **No pattern inside any glyph or on any mark under 4dp** (hatch registry). Manager's 12px hatched "not measured" square becomes a barred square.
- **In progress** = a half-disc glyph inside the tile (agent) — kit's half-filled tile is 1.49:1 on the well.
- **The 2px vertical ladder rule is deleted** (agent): rows now carry their own 3:1 rules and a line crossing them is decoration.
- **Meaning-bearing glyphs scale with text** (agent): tile 28→48, glyph 16→32, delta triangle 8→16, chips' glyphs 16→32. Kit's fixed sizes lose.
- **The tile is filled, not outlined** — **owner override, 29 September 2026**, amending the ruling above rather than contradicting it. *"The agent side is still rectangular."* With the agent's blocks turned into soft cards, three radius-6 bordered squares down the visit hub's leading lane were among the last rectangles on the screen, two of them at a 2px border. **The four silhouettes are untouched** — a ring, a half disc, a tick disc, a barred ring, same sizes, same inks — because the silhouette set is what this ruling protects and what `section_state_glyph_test.dart` proves in greyscale; an earlier survey was right to refuse to delete the tile. What goes is the border and the corner: radius 6 → 11 (`torchGlyphTileRadius`, recorded as an owner decision in the component the way `torchPillRadius` is recorded in `nav_pill.dart`, because `TiqRadii` is four materials and a 28dp tile is not a fifth), and the outline is replaced by a fill tinted from the state's own ink — the approved mockup's `.glyph`, `30px / radius 11 / rgba(238,233,223,0.08) / no border`, with fill and ink tinted together for the states that have a colour. It is the same recipe as §1.6's chips, so it is one arithmetic exercise and not two. The **required** modifier was the 2px ink-1 border and is now an ink-1 wash — a weaker channel, said plainly: its one call site prints "Not started" and a crimson REQUIRED TO SUBMIT chip in the same row, so the tile was the third statement of a fact already made twice in words.

- **And so is every other tile on a row — `RowMarkTile` and the stop number, owner override, 29 September 2026.** *"Literally you didnt change anything."* The ruling above moved the section glyph and moved nothing else, and the section glyph appears on the visit hub. `RowMarkTile` opens **every row on Me, My work and Today**: it is the outlined square holding a ring on each of Me's visit rows, and the numbered square down Today's rest-of-the-day list. Today's Next-up card, meanwhile, drew the same number as a bare mono numeral with no tile at all — two objects for one thing, and neither of them the mockup's. All of it is now one object: `MarkScale.tile` square, `torchGlyphTileRadius`, no border, the fill tinted from the mark's own ink by §1.6's `torchChipWash` for the three tones that carry a hue and `raised` flat for the two whose ink is neutral. **The eight silhouettes are untouched** — square, hollow square, travelling dots, circular arrow, half-filled triangle, disc-in-ring, chain link, barred ring — for the same reason the four are: the silhouette set is what this ruling protects. `muted` is neutral for this purpose although it is the disabled tone: its ink is `inkMute`, sub-AA on every tier it has sat on (2.79:1 → 2.48:1 Night, 2.26:1 → 2.74:1 Day), exempt under 1.4.3, and a wash of its own would be a fifth tier carrying an ink that is not trying to be read.
- **The next stop's tile is NOT amber, and the mockup's is.** The mockup tints it `rgba(255,177,98,0.16)` with a `#FFCB94` numeral — flame-700, hue 30.8°, value 1.00, inside the census's flame box, so that numeral is a **lit object** and it is the fourth on a screen §1.1 allows two. It declares no claim, so it takes its neutral form; see §1.7.

### 1.6 Chips
- **Flag chips are never crimson** (kit + agent over manager). Out of fence and flagged for review are facts, not verdicts. The single severity flag is **Sent back** (a human rejected the work).
- **One neutral treatment:** ~~fill well, 1px edge-control,~~ **fill raised, no border** (owner override, 29 September 2026), glyph + word; visual height 28 inline / 32 Field ~~/ 40 Veld~~ inside a 48dp hit box when tappable (manager's box-in-hit-area). Label 11/700 Console, 13/600 Field ~~, 16/600 Veld~~, sentence case.
- **Selected filter chip** = lifted fill ~~+ 1px ink-1 border~~ + tick + weight 700 (kit, three channels) — manager's edge-control-stays loses. Never amber, on any screen (spec's amber selected edge is overruled by all five).
- **EVERY CHIP IS A PILL AND NOTHING IS OUTLINED** — **owner override, 29 September 2026.** *"The agent side is looking completely off and not like the manager side. Please make them align and don't change the manager side, it looks perfect"*, and then, still: *"The agent side is still rectangular."* #479 took the filter chip to `torchPillRadius` on the same owner's *"let's remove this lined, rectangular style"*; it moved one widget, and the boxed radius-6 chip survived everywhere else — which a survey then found was **agent-only**, since none of The Floor, Tasks or Ask carries a `TiqChip`, `StatusChip` or `FlagChip` at all. This extends #479 to the whole family and to `ChoiceRow`. The geometry is `torchPillRadius`, the second and third grants from it, recorded here rather than added to `TiqRadii` (which deliberately carries no 999); a full-width `ChoiceRow` in column layout takes `radii.card` instead, because the mockup gives a full-width row with a subtitle `--r-row` and reserves `--r-pill` for the inline selector.
- **The fill is the level's own ink at 14%, over `raised`** (`torchChipWash`). The mockup's recipe; the tier is this product's addition and it is not cosmetic. A translucent wash gives a different ink-on-fill ratio on each of the four grounds a chip can land on, and none of them is a colour a test can name — but more decisively, the mockup is drawn in the **Night** palette, where every severity ink has 5–11:1 of headroom, and Day's do not: Day `good` is `#14664A` at 5.03:1 on the Day well, and a 14% wash of itself over that well leaves **4.17:1**, under the text floor. Over `raised` the same 14% leaves 4.99:1. Every level is declared in `tiq_contrast.dart` and measured by CI.
- **Two exceptions, both because an ink has no headroom left.** The neutral levels (Held, Live, the six neutral flags, and any cleared flag) take the `raised` tier flat rather than an ink-1 wash: their ink is ink-2 and ink-3, and `ink-3 on well` is the tightest declared pairing in the Day set at **4.52:1 against a 4.5 floor**. `raised` is more visible than the `well` it replaces on Night (1.19:1 against 1.06:1) and improves Day to 5.48:1. A **cleared** flag takes the neutral fill even when its member is crimson — ink-3 on the crimson wash is 4.28:1 on Day, and a resolved flag is not a severity anyway.
- **Critical keeps its solid fill**, which is the one chip fill in the family that clears 3:1 as a boundary (4.55:1 Night, 5.74:1 Day) and the one whose ink is dark-on-light. A severity happening *now* does not ask the reader to tell two pastels apart.
- **A disabled control still keeps its outline** (#479, unchanged): it has no fill to be seen by. `TiqChip.border` stays in the API for that reason, though no shipped level passes one.
- ~~**REQUIRED TO SUBMIT is a `StatusChip(watch)` and has no border either**, and the mockup only appears to say otherwise. Its `.req` marker does keep a `1px rgba(255,125,140,.45)` edge — but `.req` is 7.5px mono, letter-spaced and **glyphless**, a marker too small to have a silhouette, where the border is what makes it an object. The mockup's crimson *chip* — "Out of stock", `rgba(255,125,140,.18)` — carries none, and that is the object this maps onto: a full chip with a triangle and a five-word label. An outline here would re-line the exact screen the override was written about.~~ **SUPERSEDED — owner override, 29 September 2026.** *"Match the manager side please"*, a third time, and on the result of the two rounds that answered it by changing the chips and then the glyph tiles: *"Literally you didnt change anything."* The clause struck above answered the right question — *should this chip carry a border* — and the wrong one was being asked. **There is no REQUIRED TO SUBMIT chip.** The reasoning above about `.req` still stands and is why: the mockup draws that marker at 7.5px because it is a marker, and the app was drawing a full-size five-word chip on its own line under every unfinished row, four of them down a blocked hub. The fact was already stated three times — in the chip, in the count at the head of the screen, and in the blocking sentence under the primary, which names every waiting section **by name**. §9f deleted a section header on Tasks for exactly this duplication. What replaces it is the manager's own channel set at the manager's scale: the row's `SoftRowSeverity.watch` **dot** in the lane the ladder already reserves, a `SeverityMark` inline at meta size, and the word in `bad` beside the state. Three channels, none of them a rectangle, and the sentence under the primary is untouched.
- **A row that opens a section carries no chevron** — same override, same sentence. The hub drew one on all eight rungs. The manager side dropped chevrons from every row that is not a page in a stack of pages, and the argument the Ask work made is the one that bites hardest here: four stacked chevrons make an invitation read as a settings list, and this ladder shows eight. The whole card is the target, it presses, and the state tile already says there is something to open. The approved mockup's hub rows carry none.
- **Follow-up chips** = the filter chip component, 48 tall.

### 1.7 Buttons
- **Primary label:** 16/600 Field, 14/600 Console ~~, 18/700 Veld~~ (agent's argument — the commit action was carrying the smallest type on the screen).
- **Night press:** floods to flame-500 with `#0B1017` ink (kit) — one ramp step darker than the Day block so all skins press to the same colour; agent's flame-600 flood loses only on that consistency.
- **Rim + 2dp top bleed is one object** (kit) — the assistant's cut of Send's bleed is reversed.
- **One filled primary, at one call site — owner override, 29 September 2026.** Today's "Check in here" is a **solid `flame600` block carrying `onAmber` (10.65:1)** when it is granted the light in Night, with no rim and no bleed. Every other primary keeps the ruling above, and `TiqRadii.control` does not move — `radii.control` is already 16, which is the mockup's own `border-radius` for this control, so nothing about the geometry changes and the sign-in screen is untouched. It is a parameter (`TorchPrimaryButton.filled`) and not a new default, deliberately: the Night primary is "a dark block that is **lit**" because on a dark ground amber is light rather than paint, and that reading is intact everywhere the owner has not photographed. What it does not survive is Today, where the approved mockup draws this control as `.cta` — `background:#FFB162; color:#16202B` — and an outlined block among filled cards is the same complaint as an outlined tile among filled chips, one component up. **No budget moves**: §1.1's census counts connected flame-hued *regions*, and a rim is one region and a block is one region.
- **What the ladder gives Today, stated because the mockup's own answer is over budget.** The mockup's Today lights **four** amber objects — the next stop's glyph tile, the filled CTA, the progress fill and the nav circle — and §1.1 allows two in Night and one in Day. The allocation is not a matter of taste; it falls out of `TorchScope`: in **Night** the nav's active tab takes grant 1 (rung 0, added by the allocator so no route can forget the chrome it did not draw) and the primary commit takes grant 2 (rung 1); the nav circle is denied **outright** by `circleWithPrimary`, not on budget; and the tile and the bar declare nothing, so they render `raised` and `chartNeutral`. In **Day** the ladder has one rung — only a primary commit may be amber — so the CTA keeps the light and the nav tab takes its ink form. A finished route has no primary, and then the circle takes Night's second grant and Day carries **zero**, which is correct because nothing is armed. So a filled amber CTA and the amber nav tab *do* coexist under the law; what cannot is the mockup's budget, and the two objects that lose take their neutral form rather than the screen taking a third light.
- **Dialog is deleted.** A non-dismissible bottom sheet (agent's session-ended first appearance) covers every blocking case; one modal container.

### 1.8 Count stepper
Agent's layout wins: value trough leading, an adjacent [−][+] pair trailing (56×56 each, 1px rule between), mirrored by a handedness preference. Typing opens a number sheet with Cancel/Set — a stray tap cannot replace a count, which was kit's whole worry. Kit's null→minus records 0, null→plus records 1, and whole-control finding treatment stay.

**The SKU block is a card and the finding is its fill — owner override, 29 September 2026.** *"Match the manager side please."* The stock section drew its twelve products flush, divided by `Container(height: borderWidth, color: edgeStructure)`, with a zero count marked by a **3px `bad` bar at the block's full height** plus a 12dp indent to clear it — five channels on one state, and the last table on the agent side. Both halves were overtaken by §1.3's own 25 September override: `SoftRowSpec` resolves a repeated thing to a radius-22 `surface` card with a gap of ground and **no rule at all**, and §1.3 already says a severity on a card is a dot "never a bar down its leading edge". Each product is a `TorchCard` now, separated by `SoftRowSpec`'s own `gapAfter`. The finding is the approved mockup's **three** channels and no more: the card washes `torchChipWash(skin, bad)` (§1.6's recipe, so it is one arithmetic exercise and not two), the count goes `bad` from the stepper's own `zeroIsFinding`, and the word says "Out of stock". `TorchCard` gains an optional `fill` for this, defaulting to `surface`, so no console call site moves. The shoppers-switch sentence stays: it is information, not a fourth severity channel. **A hazard leaves with the bar** — it had to be a `Stack` overlay because `FigureSlot` measures itself with a `LayoutBuilder`, which cannot answer the intrinsic query a stretch child of a `Row` inside an `IntrinsicHeight` asks, and that took the too-far screen down once. A fill asks nothing of its child's height.

**`TorchBleed` appeared zero times under `sections/`, and that cost the entry header its gutter.** `SoftRowSpec` gives a list row a margin of one gutter, because a list is bled to the screen edges by its screen and the margin is what puts the card's edge back on the gutter line; `TorchShell` already spends that gutter on the body, so the repeated-entry header landed at **two** — 40dp in, while its own fields sat at 20 and the group rule above them at 20. The header is bled now and the remove button takes the gutter back explicitly, so it stops on the same line rather than riding out to the screen edge. `s6_competitive_screen_test.dart` measures the card's painted left edge against the field beneath it: 40.0 before, 20.0 after.

The same override removes the rule between **repeated entries** in the section-form grammar and the `Border(bottom: hairline)` under each row of the **outcome's dimension breakdown**, for the one reason §1.3 already gives: a line between two objects that already have edges is the table look the card grammar exists to leave behind.

### 1.9 Checkbox / choice row / toggle
Checkbox 28dp (agent; 48 at 2.0×), kit's mixed state stays deleted. Choice options radius 6 (the chip material), selected = lifted + tick + weight 700 — one selected vocabulary across chips. Toggle 52×32, thumb 26 with a tick inside, and the state word is mandatory.

### 1.10 Bottom sheet
- **Scrim 72%** (kit/agent/manager/spec) — the assistant's 88% defeats #380's "held work visible behind it". The assistant's real finding is honoured a different way: **while a sheet is up, every amber on the route beneath goes out** (the nav tab drops to its ink form, the plate's light goes off), so the sheet's TorchScope genuinely owns the screen.
- Grabber `#616465` declared hex (kit's opacity ban), max height 88%, horizontal padding = gutter, 16 below the grabber, 24 + safe area at the bottom. No stacking; a sheet that needs a sheet cross-fades its own content (kit + agent agree).
- ~~**Veld has no sheets and no scrims** (assistant): they become full-screen white routes with a 2px border and a 56dp Close row.~~ **Struck 28 September 2026** — one shape, the bottom sheet, in both skins. `TorchSheetForm`, the Close row and `TorchSheet.closeLabel` are gone with it.

### 1.11 Skeleton
Kit wins on colour: Night text-line blocks are **edge-structure fill** (3.33:1), rows and panels are their real outline at their real geometry, empty. The other four surfaces' `well` blocks are 1.12:1 — the thing the device floor forbids. The 1400ms Oatmeal travelling rule after 600ms stays (assistant's deletion loses: an 8s stall with nothing moving reads as frozen).

### 1.12 Empty state
Whole-screen: 64dp drawing from the **closed enum of three** (shelf / pin / envelope — agent's "map, shelf, box" and assistant's shelf map onto it) + display 40 with the agent's **line-count fitting rule** (1–2 lines 40, 3 lines 32, 4+ 26). In-panel or inline: no drawing, title.m/title.l headline (manager, figures). Manager's "no illustration anywhere" loses for whole-screen — the enum cannot drift and needs half a day of one illustrator.

### 1.13 Held / offline / stale colour
Held is **Oatmeal (ink-2) square on the well** — kit, figures, agent, spec. *(Amended 29 September 2026: the ink is unchanged and the tier under it is not — see §1.5. The square now sits on `raised`, and the Truffle comparison square on Truffle's own 14% wash: 4.99:1 Night, 4.06:1 Day as a graphic, both declared in `tiq_contrast.dart`.)* Manager and assistant used the Truffle `comparison` square for held, offline, session-ended and "incomplete". Truffle is the comparison series ("them, unlit") and nothing else; giving it a second meaning is exactly the failure the severity system avoids.

### 1.14 Sync chip vs held banner
Kit promoted the sync chip into a 56dp banner under every agent header; agent kept the chip in the header. **One component, two forms:** the chip is the default; the banner form renders only for NEEDS-YOU and OFFLINE-ENTIRELY. A permanent 56dp band on every screen spends the fold the manager surface spent an item defending.

### 1.15 Person row
40dp radius-6 tile, **initials only — never a photo** (agent + assistant, POPIA; kit and manager lose). Name **wraps to two lines**, middle-truncates only when a line is structurally forced (manager/assistant — "Dlamini-Mkhize" vs "Dlamini-Ndlovu"). Id is never the primary line; kit's long-press "Copy id" stays; the unknown state shows the id in mono.ident.

### 1.16 Plate
> **OWNER OVERRIDE — 28 September 2026, on The Floor. The plate's picture is the PLACE in scope, not a shelf.** It carried the shelf photograph of the outlet at the top of the decision list. The owner asked for the noise to go — the seeded "photos" are blocks of random colour — and then for something better than a replacement shelf: *"or rather by city or territory — an image of that specific place or city."* So the plate shows a view of the territory currently filtered, and it **changes when the filter changes**, which is also what makes the scope control legible. Four rules came with it, and they are the whole of why this is allowed at all:
> * **A place image is context; a shelf photograph is evidence.** A picture of a shelf directly above a list of shelf decisions is a picture a manager can act on, and this one never was a reading of any of them. Nobody mistakes a street at sunrise for a stock count.
> * **The data says what each one is, and the plate says it out loud.** Two pipelines, both committing their output and neither called at seed time: `backend/scripts/generate-place-images.ts` draws one from a prompt against the Gemini image API, and `backend/scripts/import-place-images.ts` brings in a photograph the owner supplied from an original committed under `assets/places/supplied/`. `place_images.source` is `NOT NULL` and is `generated` or `supplied`; the API answers `X-Image-Source`; the plate speaks "an illustration of the area, not a photograph from a visit" or "a photograph of the area, not from a visit", and an origin nobody stated is spoken as unstated rather than defaulted. An unrecognised value throws in the seed loader and again in the seed writer. **The clause that never moves is "not from a visit"** — it is a fact about which table the row lives in, not about how the picture was made, and a real photograph is if anything more mistakable for evidence than a drawing. The marker travels the whole way or it is not a marker.
> * **Supplied images are the owner's to license, and the generator's constraints do not apply to them.** No readable signage, no brand marks, no identifiable faces are instructions to a *model*; nobody instructed the owner's camera. Recorded in the manifest, not assumed. Torchlight Aisle §9g.
> * **They live in a table of their own, never in `photos`.** `photos` is visit evidence, the review strip and the pin-dispute storefront — each with a visit, a GPS tag and a capture time, each hashed by the fraud engine. A place image has none of those and must never acquire them. A separate table makes "this can never be read as evidence" structural rather than a `WHERE source <>` somebody forgets.
> * **A generated image is NEVER the fallback for a missing real photograph.** The no-picture state keeps its drawing and its sentence, everywhere. An invented shelf where a real one is missing is fabricated evidence; an invented townscape where a real one is missing is a smaller lie and still a lie. The sentence names the scope, so "no picture of Gauteng North" and "no picture anywhere" stay different facts.
>
> "All territories" gets **its own generated image** — a national trade route at first light — rather than borrowing one province's, because it is the scope the screen opens in.

> **OWNER OVERRIDE — 25 September 2026, on The Floor.** The plate is an **inset rounded card** (gutter margins, radius 28, the shell's console inset above it), not a full-bleed band, and it carries **no printed provenance caption** — the outlet and capture time are the image's semantic label instead. Its fold budget is `min(clamp(0.40 × vh, 200, 312), vh − 440)`: a card also spends the top inset and a gap beneath itself, so the old 0.44/360 bought a bigger object and cost the list the third decision card the owner's reference shows. Everything else below stands, including the strip light, the tone and the fallback.

Kit's **fixed perspective fallback plus a sentence** wins over manager's data-driven spacing (nobody decodes line spacing). Manager wins on **height** (`min(clamp(0.44·vh, 200, 360), vh − 440)`, collapsed 96dp band under 200), **bytes** (lossy WebP + alpha, ≤60 kB — kit's PNG loses), **provenance caption**, and **"Dark frame — mean brightness 11%"** rather than a cause. The Panel's Palladian@10% top rim is **cut** everywhere (assistant; figures measured 1.32:1) — it costs a paint and says nothing.

### 1.17 Figures and type
> **OWNER OVERRIDE — 28 September 2026, on the Execution overview. A rate's axis stops at a hundred, and a figure block's delta stands on the figure's own baseline.** Two rulings from one sentence — *"the chart must be realistic please fix it. And remove the rectangular style."* See `torchlight-aisle.md` §9f.
> * **`niceScale` takes a `ChartDomain`.** It divided the padded span by the tick count and snapped the quotient up the 1-2-5 ladder, which overshoots near a boundary: availability at 64–73 against the published 95% standard drew six readings inside an axis labelled **40 to 120**, and a healthy run rounded out to **105**. A percentage cannot be either. `ChartDomain.rate` is 0–100 and `TrendChart` passes it whenever the unit is percent; only the padding is clipped, so a server that sends 103% is still drawn at 103%. The step is now searched from below and the finest one inside the tick budget wins, so the run fills the plot it is given.
> * **`StatTile.deltaOnBaseline`.** §1.16's plate hero has always paired the figure and its movement on one baseline; this is the same arrangement for a hero that lives in a card. A baseline delta **drops its `comparedTo`** — a sentence beside a `figure.l` takes two further lines and the pair stops reading as a pair — and the caller states the comparison on the card's one supporting line.
> * **A figure block is four things and a severity is a dot.** The overview's headline figure was `StatTile(lead: true, severity: …)`, the one configuration in the kit that draws a border, at `radii.chip` — a crimson rectangle among radius-22 cards — holding five stacked elements. Its indicator and territory rows each carried a full-width `Meter` of the percentage the figure beside it had already printed, plus a `SeverityMark` triangle in the trailing column. The outline, the meters and the triangles are gone; the meter's target tick is a number in words on each row's meta line, and the standing is the 8dp dot §1.3 already declared.

- **Formatter:** figures' `TiqNumber` and `FigureSlot` (measured fitting incl. affixes, `TextScaler.scale()` not a factor, no `FittedBox` in baseline rows) replace kit's glyph-count table, agent's and assistant's fitting rules.
- **Weights:** figure roles JBM **600**, hero/display **700** (kit's token sheet; figures' 500 loses). **Tracking 0 on every mono role** (figures; kit's −2.5% hero was an Archivo instruction).
- **Mono in prose:** 0.94em of the surrounding role, letterSpacing 0 (assistant); agent's −1% loses to the no-negative-tracking rule.
- **Eyebrow is legal in three places only:** a stat tile's label, a hero/plate figure's label, a block label inside a panel ("WORST FIRST"). **Owner override, 25 September 2026: The Floor's one section marker is a fourth place** — `NEEDS A DECISION` is the uppercase kicker on the ground, with no rule and no count, because the reference the owner signed off has no line across that screen and a line there is one more box on a screen they twice asked to be less boxy. ~~Every other screen keeps the knocked-out rule; this is not a licence to delete it.~~ **SUPERSEDED, 25 September 2026 — same day, later.** The owner looked at the finished Floor and said to make its design *"global and everywhere on the app"*. The uppercase kicker on the ground is therefore **the** screen-level section marker, on every screen, and `SectionRule` is that component: no line, no count chip, `emptyLine` and the ghost action kept. The reasoning the original ruling rested on is answered rather than dropped — on a screen whose rows are cards with a gap of ground between them, a line across that air is a second boundary saying what the gap has already said, which is the "one more box" the owner objected to twice; and this kicker is not the one the component replaced, because that one was amber and numbered and this one is ink-2 with the count in its own words. **The string stays sentence case** — the uppercase is presentation, so a screen reader, a search index and the PDF exporter are handed the sentence, and the component still asserts against a call site that shouts in the data.
- **Delta magnitude: unsigned, always. Owner override, 25 September 2026.** `Delta` printed the sign beside its own triangle on the argument that "the sign is the arithmetic and the triangle is the reading". The owner read `▼ −19 pts` on The Floor's hero and cut all three parts of the redundancy: the triangle already says *down*, in a silhouette that survives greyscale, a 1-bit render and a 40%-backlit panel, where a three-pixel glyph does not. **The unit is the caller's call and goes wherever it is noise** — on a score it is, because a territory-health figure is not measured in anything else and the hero above carries no suffix either. The word is not lost: it moves into the delta's semantics sentence, which already carries the direction word and the verdict word, so colour and shape are still not the only carriers. The formatter's true minus (U+2212, never a hyphen) is untouched — it is a property of `TiqNumber`, and every *level* that is genuinely negative still prints it.
- **A screen that can be scoped can be unscoped, and says which slice it is showing.** The Floor shipped printing a territory name it had no control for — the fifth capability lost to a migration in this project. The window-and-territory control is one implementation (`features/dashboard/presentation/dashboard_filters.dart`) with two presentations: the overview's rail, and The Floor's plate. ~~The Floor's is the plate eyebrow, which is a control because the words already name both facts and the signed-off reference has no filter chrome.~~ **SUPERSEDED — owner override, 28 September 2026.** The invisible control was the honest reading of a reference with no filter chrome, and it failed the only test that matters: *"I wouldn't see it if I'm new on the app. Please make it a visible button or something matching the style of the app."* The Floor's presentation is now **`PlateScopeChip`**, at the top of the plate: the app's filter-chip grammar (radius `chip`, 1px `edgeControl` edge, the `label` role, the standard press, **never amber** per §1.6) with two departures, both because it stands on a picture rather than on the ground — it always carries a `surface` fill, since an unselected rail chip is transparent and a transparent label on a photograph is unreadable; and *filtered* is an `ink1` edge and a heavier name rather than a tick, because a tick means "chosen from these options" in a rail of several and there is one chip here. It prints the scope **and** the window, so it states where you are as well as offering to change it, and the eyebrow line is dropped from the hero cluster rather than naming the territory twice on one card. **It lives in the photographic band and not in the cluster, and that is arithmetic**: the cluster sits inside the plate's `FittedBox`, so every dp of control up there comes straight off the hero figure — the defect `floor_proportion_test.dart` exists to catch. Rules that came out of building it: the control **scopes every block or it is a lie** — a screen that relabels itself and keeps its figures claims an answer it did not compute; where the client cannot scope a block (`GET /alerts` and `GET /tasks` take no territory), that block is **withheld with a sentence**, never shown unscoped under a scoped heading; clearing is one tap and the clear affordance exists only while something is filtered; and the empty result is a designed state naming the slice, because an empty slice and an empty world are different facts.
- **Trend chart:** 208 Console phone / 232 Field ~~/ 180 Veld~~ / 260 at ≥600dp; assistant's 160 loses (with a 38dp gutter it leaves ~120dp of plot). Gridlines `lifted`. Ranked label wraps two lines then middle-truncates (assistant); cap 8 rows.

### 1.18 Progress-to-reward bar
One component: 8dp track (12 at 2.0×), lifted fill + 1px edge-structure outline, `chart-neutral` fill, ink-1 milestone ticks breaking the top edge, the words always beneath. Reached: fill goes `good` and a filled circle sits at the tick (agent/manager); figures' "good after the first milestone" loses — clearing one of three milestones is not a verdict. Never amber (three surfaces over agent).

### 1.19 Meter track
Figures wins: 4dp Console / 6dp Field ~~/ 8dp Veld~~, **outlined only in the empty, null, loading and hatched states** (a filled track needs no edge). Kit's always-outlined 6dp loses.

### 1.20 Provisional / reconciliation
- **The agent app never shows a provisional score** (agent); `visit_outcome_screen.dart`'s no-guess stands. Kit's numeric-field provisional state is deleted.
- **One Reconciliation line component, two string sets:** agent second person ("Now scored 71 — it was 84 when you saw it"), console third person ("Scored 71 — the phone showed 84"). Both figures mono; neutral square glyph; never good/bad.
- **Provisional marker** (dotted underline + word) exists only on the console, only for server-stamped provisional figures.

### 1.21 Decision sheet
Merged: kit's **proof block** (counts in JBM, section-state glyphs leading each line, both actions busy until the count resolves) + agent's **two-step in-sheet confirm** ("Delete and start over", bad-outlined, cross-faded, never a second sheet) + agent's **stale-fix branch** (>12h: "Check in again" is the primary). Kit's undo toast after start-over is dropped — the two-step is the guard. The manager's Confirm sheet and the assistant's Start-over sheet are instances.

### 1.22 Skip-reason picker
Agent's version wins (consequence line under each reason, third-can't-confirm warning, check-in variant with different reasons, saved reason appears on the submit gate) with kit's states folded in (already skipped, no reasons configured, offline held, dismissal is safe).

### 1.23 Icon button toggled-on (torch, skin)
Solid Abyssal block, **ink-1 glyph**, the word ON (agent's Phase 2). Kit's Day ~~/Veld~~ "amber glyph" — inherited from the spec — is overruled: a toggle state is a label. This is the one place the reconciled system corrects the spec's own text.

### 1.24 Session ended
A **bottom sheet** over the live screen (agent/manager), non-dismissible on first appearance, held work visible behind it; kit's full-screen state loses because the sheet delivers the proof block *and* the screen. After "Not now", the 44dp persistent line under every header (agent) — the assistant's composer band is that line.

---

### 1.25 One spacing scale, and it is the manager's

> **OWNER OVERRIDE — 29 September 2026. THERE IS ONE SPACING SCALE, AND IT IS THE CONSOLE'S.**
>
> > *"Fix the spacing also please check if everything matches with the manager side"*
>
> Said after *"match the manager side please"* and *"don't change the manager side, it looks perfect"* the same day. With type unified on a sibling branch (#488, *"There is one type scale, and it is the manager's"*), spacing is the last axis on which the agent side differs **by construction** rather than by drift.
>
> **NOTE FOR WHOEVER INTEGRATES THIS WITH #488.** This branch is cut from `feat/chip-pills`, which does **not** contain #488 — that PR merged into `feat/agent-row-marks` an hour after `feat/agent-row-marks` had already merged into `feat/chip-pills`, so the two are siblings rather than a stack. #488 adds a paragraph to §1.17 headed **"WHAT IS NOT STRUCK — spacing"**, which says `TiqSpace.field` is untouched and that *"a 44dp target on a phone used in a forecourt is a different change and nobody has asked for it"*. It also adds, to §1.6 and §1.7, the sentence that `TiqSpace.field` is deliberately untouched by the type unification. **Those sentences are superseded by this clause and should be struck, not deleted, when the two land together** — it was true on the day it was written, and it named the right condition: somebody has now asked. Git will not flag it, because the two changes touch different lines of the same file.
>
> **TWO KINDS OF TOKEN LIVE IN `TiqSpace`, AND THEY ARE NOT THE SAME QUESTION.** `gutterWide`, `rowMinHeight`, `blockGap` and `intraBlock` are **visual rhythm**: how much air a screen puts between things, and how tall a row stands when its content does not decide. `tapTarget`, `chipHeight` and `primaryActionHeight` are **thumb reach**: how big a thing has to be to be hit. Different evidence, so they moved in separate commits and either can be reverted without the other.
>
> | token | was (field) | now | kind |
> |---|---|---|---|
> | `gutter` | s5 | s5 | — already the same |
> | `gutterWide` | s5 | **s8** | rhythm |
> | `rowMinHeight` | 64 | **44** | rhythm |
> | `blockGap` | s7 | **s6** | rhythm |
> | `intraBlock` | s4 | **s3** | rhythm |
> | `tapTarget` | 48 | **44** | touch |
> | `chipHeight` | 48 | **44** | touch |
> | `primaryActionHeight` | s9 (56) | **44** | touch |
>
> **WHAT WAS TRADED, kept rather than deleted.** A 64dp row and a 32dp block gap are what a list looks like when it is scanned standing up, at arm's length, one-handed, on a cheap panel at 40% backlight, often in direct sunlight — the same premise that gave `TiqType.field` its larger prose, and the layout half of the same answer: more air per row means fewer rows compete for one glance, and a 64dp floor is tall enough that a two-line outlet name never crowds its status word. `gutterWide` held the phone gutter at every width because the field surface is phone-only and 1080dp was a case nobody had.
>
> **WHAT IT BUYS.** One rhythm across the product, which is what the owner asked for four times in one day. **WHAT IT COSTS:** about a third of each row's floor and a quarter of the air between blocks, on exactly the screens read outdoors — against which more of the screen is now the screen, which is the compensation the owner was after. Measured on the declared-shape goldens: the thumb zone loses 8dp on all five screens that have one (`intraBlock` twice), and My work's outbox returns a second row above the fold at 390×844.
>
> **TOUCH — what it costs, said plainly.** Every tap target on the agent side drops from **48dp to 44dp**, every chip from 48 to 44, and the commit action from 56dp to 44dp. 48dp existed because an agent works one-handed, in direct sunlight, often with a box under the other arm and a phone that is not theirs; it is the Material floor and one step of margin above the accessibility one. **44dp is the WCAG 2.5.5 (AAA) minimum** — the floor rather than a margin above it — and it is what the manager side has run from the start with nobody filing it, so it is not out of contract and it is the number the owner is pointing at. That is the whole of the trade, and it is why the touch change is its own commit: reverting it is one revert and does not take the rhythm with it.
>
> **ONE FLOOR DID NOT MOVE, and it is worth knowing before anyone panics.** `torchTapTarget` in `button/torch_button.dart` reads `skin.space.tapTarget < 48 ? 48 : skin.space.tapTarget` — a hard 48 for text and glyph actions at **both** densities, written before this change and unaffected by it. The smallest targets in the product therefore stay 48dp on both sides. What drops to 44 is the row floor, the chip, the block button and the generic `space.tapTarget` constraint.
>
> **`chipHeight` WAS A DEAD TOKEN.** Nothing in `lib/` read it: `TorchFilterChip.heightFor` restated 44/48 as its own switch on density, so the same ruling was written in two places, which is how two copies of one number drift apart. It reads `skin.space.chipHeight` now. The console value is 44 either way, so no manager pixel moved when it was rewired — proved by sha256, not assumed.
>
> **This strikes §1.3's "standard 64 (Field lists)" and its "tappable targets are ≥48 everywhere", and §1.6's "inside a 48dp hit box when tappable".** All three were density rulings about the thumb, and all three are overridden here rather than reinterpreted. §1.6's *visual* chip height of 28/32 is NOT struck — that is a separate number in a separate file and it still branches.
>
>
> **IF THE FIELD SCALE EVER RETURNS, ITS RATIONALE RETURNS WITH IT.** The paragraphs above are not withdrawn, they are outranked, and they are kept in `TiqSpace.field`'s doc comment as well as here. A future reader restoring 64dp rows or 48dp targets is restoring a decision, not a number, and the decision is written down in both places.
>
> **WHAT THIS DOES NOT REACH.** Eight widgets outside `TiqSpace` still branch on `TiqDensity` for geometry that is not spacing, and they are unchanged because they are separate rulings with their own written reasons — header height 72/96 (§1.2), chip visual height 28/32 (§1.6), filter-chip height 44/48, trough min height 44/56, meter track 4/6 (§1.19), stat-tile inset 16/20 and floor 88/96 (§1.4), trend-chart plot 208/232 (§1.17), and the assistant card's copy of the last one. They are listed so nobody has to re-find them.

## 2. Duplicates to merge

| Designed as | Survivor |
|---|---|
| Kit *Torch precedence*, Figures *AmberLedger*, Agent *Amber ledger*, Manager *TiqLedger*, Assistant *The amber ledger* + `litObject` arbiter | **TorchScope** (kit API + figures' static per-phase resolution + figures' pixel golden + manager's lint) |
| Kit *Kit foundations*, Figures *MotionBudget*, Agent *Glyph scale rule*, Assistant *Separation rule* | **TiqSkin foundations** (tokens, densities, radii, depth, motion) with MotionBudget, the separation tiers and the glyph-scale rule as sub-patterns |
| Kit *Soft row*, Agent *Soft row*, Manager *Decision row* + *Held-work row*, Assistant list rows | **Soft row** (list / standalone; compact / standard / tall; severity bar; live outbox and held-work as configurations) |
| Kit *Person row*, Agent *Person row*, Manager *Person row*, Assistant *Person row in an answer* | **Person row** |
| Kit *Stat tile* (as Meter-minus-track), Figures *StatTile* + no-data/low-sample, Agent *Stat tile that admits no data*, Manager *Stat tile (console)* + *Lead indicator*, Assistant *Stat tile cell* + no-data + updated | **StatTile** (+ StatCluster); `lead` variant; `updated` state |
| Kit *Meter*, Figures *Meter*, Kit *Progress bar*, Agent *Progress-to-reward bar*, Manager *Progress-to-reward bar*, Figures' reward variant | **Meter** (in-tile) and **Progress bar** (+ reward variant) — two components, both built on one `TrackPainter` |
| Kit *Section state glyph*, Agent *Section state glyph — four states*, Figures' barred ring, Manager's not-measured mark | **Section state glyph** (four silhouettes) and **Severity & measurement mark set** (five marks incl. barred square) |
| Kit *Flag chip family*, Agent *Flag chip*, Manager *Flag chip* | **Flag chip** (six members + Sent back) |
| Kit *Status chip*, Figures *held chip*, Agent *Sync chip*, Kit *Offline / held banner*, Manager *Offline / stale banner*, Manager *Held-work row* | **Status chip** (five levels) and **Sync status** (chip default, banner form for Needs-you / Offline) |
| Kit *Decision sheet*, Agent *Decision sheet*, Manager *Confirm sheet*, Assistant *Start-over decision sheet*, Kit *Dialog* | **Decision sheet** (resume / start-over / confirm-destructive); Dialog deleted |
| Kit *Skip-reason picker*, Agent *Skip-reason picker* | **Skip-reason picker** |
| Kit *Loading skeleton*, Figures *DataSkeleton*, Agent *Skeleton grammar*, Manager *Console skeleton set*, Assistant *Artifact skeleton* | **Skeleton** |
| Kit *Empty state*, Figures *DataEmpty*, Agent *Empty state grammar*, Manager *Empty state (console)*, Assistant *Empty first-run state* | **Empty state** (whole-screen / inline) |
| Kit *Error state*, Figures *DataError and stale*, Manager *Inline error and retry*, Assistant *Error states*, Kit/Agent/Manager/Assistant *Session ended* | **Error state** (whole-screen / inline) and **Session-ended sheet** |
| Kit *Section divider*, Manager *Section rule*, Assistant's knocked-out callout/sources rules | **Section rule** |
| Kit *Delta* (inside stat tile), Figures *Delta*, Manager *Delta mark*, `DeltaChip`, `DeltaPill`, `TileDelta.text` | **Delta** (drawn triangle; the three existing widgets are deleted) |
| Kit *Plate*, Manager *Photographic plate and fallback* | **Plate** |
| Kit *Floating pill navigation* + *Nav circle*, Agent *Floating nav pill and action circle*, Manager *Floating nav pill + primary circle*, Assistant's underbar | **Nav pill** + **Nav circle** |
| Kit *App header*, Agent *Agent shell*, Manager *Console shell*, Assistant *screen shell* + *bottom stack* | **Shell** (Agent / Console profiles) + **App header** |
| Kit *Toast*, Manager *Console receipt toast* | **Toast** |
| Kit *Text field* + *Numeric field*, Agent *Trough input and field grammar* | **Text field**, **Numeric field** |
| Kit *Count stepper*, Agent *Count stepper* | **Count stepper** |
| Figures *ScoreMark*, *ScoreHero*, *BandScale*, Agent *Outcome — scored* hero; the cut *ScoreArc* | **ScoreHero** + **BandScale** + **ScoreMark**; ScoreArc stays cut |
| Figures *Provisional and final*, Manager *Provisional / final figure and reconciliation line*, Agent *Reconciliation line*, Assistant *updated figure* | **Reconciliation line** (+ console-only Provisional marker) |
| Figures *RankedBarRow/List/diverging*, Manager *Ranked bar row*, Assistant *Ranked bars block* | **RankedBarList** |
| Figures *TrendChart* + *ChartLegend* + *ChartFrame* + *ScrubReadout*, Manager *Trend chart + legend*, Assistant *Trend chart block* + *Chart legend* | **TrendChart**, **ChartLegend**, **ChartFrame**, **ScrubReadout** |
| Figures *Sparkline*, Manager *Sparkline cell* | **Sparkline** |
| Kit *Icon button*, Manager *Console icon button*, Assistant *Answer actions* | **Icon button** (`semanticLabel` required) |
| Kit *Filter chip*, Manager *Filter rail*, Assistant *Follow-up chips* | **Filter chip** (+ rail) |
| Assistant *Voice slot* | deleted until a speech capability exists |

---

## 3. Canonical component list

*New* = does not exist today. *Replaces* = an existing widget or convention is deleted when it lands.

### A. Foundations (patterns, no pixels)
1. **TiqSkin** — one `ThemeExtension`, three factories, two densities; SPACE s1–s11, five radii, four depth levels, motion scale. *Replaces* TiqColors, LumenPalette, LumenGlass, AppColors, status_pill_colors, 34 BoxShadow literals.
2. **TorchScope** — resolves each route's declared amber claims by fixed precedence; asserts in debug, degrades in release. *New.*
3. **TiqNumber + FigureSlot** — the one locale formatter and the one figure primitive (mono run, Onest affix, measured fitting, null = em dash). *Replaces* `NumberFormat('#,##0.#','en_US')` and every `toStringAsFixed`.
4. **MotionBudget** — single `still` boolean (disableAnimations ~~∨ Veld~~ ∨ powerSave). *New.*
5. **HatchPaint registry** — four patterns (not-measured ↘, negative ↗, low-sample outline, provisional outline+dots); never on a glyph or under 4dp. *New.*
6. **Separation tiers, glyph-scale rule, press/focus/haptics, fold budget, breakpoints** — cross-cutting rules (section 4). *New.*

### B. Chrome
7. **Shell** (Agent / Console) — gutter, header ceiling, scroll frame, bottom region (tab-root row / thumb zone / skin-cycle-only zone). *Replaces* Scaffold+AppBar usage.
8. **App header** — title, capped subtitle, one trailing icon button, flag-chip wrap with expander. *Replaces* AppBar.
9. **Nav pill** — four slots, amber active pill in Night, measured labels ~~, docked in Veld~~. *Replaces* the bottom nav.
10. **Nav circle** — the role's standing action; amber only when expected and no primary exists. *New.*
11. **Skin cycle** — 56dp three-glyph toggle; header on tab roots, thumb zone elsewhere. *New.*
12. **Thumb zone** — 96dp region with the primary and the skin cycle. *Replaces* ad-hoc bottom buttons.
13. **Sync status** — chip (default) / banner (needs-you, offline). *Replaces* the sync chip.
14. **Menu sheet** — grouped overflow destinations. *New.*
15. **Toast** — neutral / success / failure / held; above the pill. *Replaces* SnackBar.

### C. Surfaces and containers
16. **Panel** — the one panel material (AI cluster, forms, sheet bodies); no rim. *Replaces* GlassPane.
17. **Plate** — baked WebP, strip light, fold-budget height, fixed fallback + sentence. *New.*
18. **Soft row** — list / standalone; compact / standard / tall; severity bar; live outbox, held-work and decision rows are configurations. *Replaces* ListTile/Card usage.
19. **Section rule** — the knocked-out title.m marker; count and action slots; sticky. *Replaces* uppercase eyebrows as section markers.
20. **Bottom sheet** — 72% scrim, no blur, no stacking ~~, full-screen route in Veld~~. *Replaces* showModalBottomSheet styling.
21. **Decision sheet** — proof block + resume / start-over / confirm-destructive. *New (#374).*
22. **Skip-reason picker** — reasons with consequences, check-in variant. *New (#395).*
23. **Session-ended sheet** — a state, held work behind it; persistent line afterwards. *New (#380/#392).*
24. **Skeleton** — real outlines and edge-structure text blocks; Oatmeal rule after 600ms. *Replaces* CircularProgressIndicator.
25. **Empty state** — whole-screen (closed enum drawing + display) / inline. *Replaces* centred "No data".
26. **Error state** — whole-screen / inline; one Retry per region; sanitised messages. *Replaces* raw error text.
27. **Pagination footer** — "Showing the 20 riskiest of 74" + unscored note. *New.*

### D. Controls
28. **Primary button** — commit; rim + bleed Night, block Day ~~/Veld~~; BarNote when disabled. *Replaces* ElevatedButton.
29. **Secondary button** — ghost. *Replaces* OutlinedButton.
30. **Tertiary button** — underlined text action, 48dp target. *Replaces* TextButton.
31. **Destructive button** — outlined crimson; solid only as a sheet's confirming press. *New.*
32. **Icon button** — `semanticLabel` required; toggled-on is an Abyssal block + word. *Replaces* 26 unlabelled IconButtons.
33. **Text field** — the trough. *Replaces* TextField decoration.
34. **Numeric field** — mono, right-aligned, leading-digit overflow anchor, locale decimal. *New.*
35. **Count stepper** — trough + adjacent ± pair; zero-as-finding. *Replaces* the current stepper.
36. **Toggle** — tick in thumb + state word; unknown binaries are choice rows. *Replaces* Switch.
37. **Checkbox** — 28dp, no mixed state. *Replaces* Checkbox.
38. **Choice row** — 2–4 options, nothing-selected is a state. *New.*
39. **Filter chip + rail** — selected = lifted + ink-1 border + tick. *Replaces* ChoiceChip.
40. **Verdict control** — three stacked rows + commit (fraud). *New.*

### E. Marks and status
41. **Status chip** — Critical / Watch / On target / Held / Live; hue + silhouette + word in one token. *Replaces* status pills.
42. **Flag chip** — six neutral members + Sent back. *New (#393).*
43. **Severity & measurement mark set** — five drawn marks. *New.*
44. **Section state glyph** — not started / in progress / done / can't confirm. *Replaces* tick/half-circle/ring (#375).
45. **Delta** — drawn triangle, server sentiment, baseline-sample suppression. *Replaces* DeltaChip, DeltaPill, `TileDelta.text`.
46. **Person row** — name, role, outlet; never an id. *New (#399/#400).*
47. **Reconciliation line** (+ console Provisional marker). *New (#377/#390/#398).*
48. **Progress bar** (+ reward variant). *New (#391/#396).*

### F. Figures and charts
49. **StatTile** (+ no-data, low-sample, updated, lead) and **StatCluster**. *Replaces* rich_figures tiles.
50. **Meter** — in-tile bar with ink-1 target tick. *New.*
51. **RankedBarList** (+ diverging). *Repoints* charts.dart painters.
52. **TrendChart**, **ChartLegend**, **ChartFrame**, **ScrubReadout**. *Repoints* charts.dart.
53. **Sparkline** — RepaintBoundary + cached Picture. *New.*
54. **ScoreHero**, **BandScale** (threshold marks, no washes), **ScoreMark**. *Replaces* the centred outcome hero and the blur-shadowed band scale.
55. **DimensionBreakdown** — six rows, hatch for unmeasured. *Replaces* the outcome breakdown.
56. **TableTwin** — the numbers behind every visual. *New.*

### G. Assistant
57. **Question composer** (Send = primary in icon form, Stop while streaming). *Replaces* the current input.
58. **Question bubble**, **Working-steps rail + summary**, **Headline sentence**, **Streaming body**, **Callout** (section rule + body), **Outside-data band + inline mark**, **Source list/row**, **Unsupported view note**, **History sheet**. *Replaces* the current chat rendering.

### H. Capture
59. **Photo pre-capture card** (Phase 1), **Camera** (Phase 2, Night tokens), **Photo review strip/viewer**. *Replaces* the raw image_picker handoff.
60. **Submit gate task row** — a Soft row configuration with the severity bar. *Replaces* the current gate list.

---

## 4. Cross-cutting rules

**Amber.** Burning Flame is emitted light, never a label. Night: at most two amber objects in the composed frame, counted — the nav's active pill is object 1 whenever the nav renders; content has one grant on a tabbed route and two on an untabbed one (in-visit, sheet, full-screen state). Day ~~/Veld~~: exactly one, the primary commit block, and zero when nothing is armed. Precedence: primary commit → plate strip light → chart focus (one bar or one series) → nav circle (only on a route with no primary) → live pulse (one per route, presence only). A route may declare one `subject` override. The text-field focus rule counts and fits because the keyboard hides the nav. Amber is never: a chip, flag, status, badge, tick, divider, gridline, axis, toggle, toast, skeleton, sparkline, delta, empty state, icon tint, section marker, word, or anything repeated. Tokens: flame-600 (light), flame-500 (pressed), flame-700 (focus rule), flame-bloom `#FFF1DE` (gradient stop); no others exist. Enforced three ways: TorchScope asserts on over-claim; a pixel golden connected-components every flame-hued region per route × phase × skin and fails above the budget; a lint forbids `flame*` outside an allowlist of emitter widgets. While a modal sheet is up, every amber beneath it is extinguished.

**Non-colour encoding.** Every hue-coded distinction carries a second channel — shape, weight, dash, hatch, outline, or a word — and the second channel is the one that must survive greyscale, deuteranopia, glare and a screen reader. Severity is crimson at two commitment levels (outline = Watch, solid = Critical) + silhouette + word; there is no amber warning. Held is Oatmeal + square + word; Truffle is the comparison series and nothing else. Selection is fill + weight + mark. Nothing is identified by a fill step alone in Night: anything with a perceivable boundary carries a real edge (edge-structure 3:1 for containers, edge-control for controls). Opacity is banned as a state channel; composited values are declared hexes. Every meaningful glyph has a `semanticLabel` bound in the same token as its hue.

**2.0× text.** `textScaler` clamps at 2.0 (hero.figure at 1.6, applied to `TextScaler.scale()`, never a factor). Meaning-bearing glyphs scale with it (tile 28→48, triangle 8→16, chip glyph 16→32); decorative marks stay fixed; tracks scale at half rate. Every label wraps to two lines at every size; nothing is pinned; outlet names middle-truncate before status words. Nav labels are measured and go icon-only as a whole. Tile grids collapse on `LayoutBuilder` width, never on a text-scale guess. Headers cap at 40% of the viewport, then scroll. Sheets never resize under a thumb. Afrikaans: a pseudo-localisation CI pass renders every label at 1.4× width and fails on overflow.

~~**Veld.** A third theme, single density, white ground, `#0E141A` ink, nothing under 9:1 for text or 15:1 for borders; every hairline a 2px `#1B2632` border; every shadow, gradient, rim, bloom, scrim and blur removed, not softened; sheets become full-screen routes; the nav docks. Type steps by declared members (body 17, label 16, meta 14, title.m 18, figure.m 24), 600 weight floor. Targets 56, rows 64, gutter 24, block gap 40. One amber block, the primary, ink `#0E141A` on it. Entered by the skin cycle, by solar elevation on a state change, or by memory; never auto-expires. Motion off. The plate, sparklines, trend charts, maps and thumbnails do not render; figure lists replace them.~~

**Veld — STRUCK, 28 September 2026, by owner decision.** There are two skins: Night and Day. The paragraph above is kept struck through rather than deleted because it is the whole of what was removed, and a reader who finds it has to find the decision beside it. **What was given up is outdoor legibility for field agents**, and nothing replaces it: an agent in a forecourt at 13:00 reads Day. The contrast walk now iterates four skin × density pairs, `ContrastRole` has no `veldText`/`veldBorder`, and a skin declares no floor of its own — the role's floor is the whole requirement everywhere. See the block at the top of this document.

**Blur / shadow / paint budget.** Zero `BackdropFilter`, `ShaderMask`, `ImageFiltered`, `saveLayer`. Night: zero `BoxShadow`; Day: sh1/sh2/sh3, ≤6 per screen. Every bloom is a `LinearGradient` in the existing draw call; ≤12 gradient decorations per screen, none inside a `ListView.builder` row (hatches are painter lines there). One app-wide `Ticker`, three subscribers. Plates are baked server-side (the chroma reduction, the skin's own `[plateLift, plateCeiling]` range, alpha dissolve, ≤60 kB WebP) and decoded at `cacheWidth`. Sparklines cache to a `Picture` in a `RepaintBoundary`. A profile test fails the build at p95 raster > 12 ms on the dashboard and answer routes.

**Unknown vs zero.** A measured zero renders "0", never suppressed, with a flat delta bar; a zero that is a finding takes the finding treatment. A null renders an em dash in ink-3 at the figure's own role and face, unit suppressed, no delta, and a sentence in words ("No visits in this window"). Not measured (a dimension) renders an em dash plus a full-width falling hatch on its track plus a reason. Can't confirm (a section) is a barred ring plus the words and is excluded from the readiness count. Low sample keeps the figure at ink-2, outlines the fill, and removes the delta — for a thin baseline too. A tile is never hidden; a grey "Unknown" chip is never shown; an all-zero list is a finding, not an empty state; a delta never stands beside nothing.

---

## 5. Build order

**Phase 0 — foundations (no screens change).** TiqSkin is landed; add TorchScope, TiqNumber + FigureSlot, MotionBudget (`powerSave = const false` with a ticket), the hatch registry, the generated contrast test, the `pyftsubset` codepoint guard (and the test that no Dart source references U+25B2/U+25BC), and the pixel-count amber golden harness. Buy three sub-R2000 Androids and photograph the Night dashboard at 40% backlight before anything else is committed.

**Phase 1 — the five unblockers, Night goldens first.**
1. **Soft row** (list + standalone, three densities, severity bar) — every list on all 60 screens.
2. **Button family** (primary, secondary, tertiary, destructive, icon) — every commit and every thumb zone.
3. **Shell + App header + Nav pill + Nav circle + Skin cycle** — every route's frame.
4. **Status chip + Flag chip + Severity mark set + Section state glyph** — every row's state.
5. **StatTile / StatCluster / Meter / Delta** — every figure on manager and agent surfaces.

**Phase 2 — containers and inputs.** Bottom sheet, Decision sheet, Skip-reason picker, Session-ended sheet; Skeleton, Empty, Error; Text field, Numeric field, Count stepper, Toggle, Checkbox, Choice row, Filter chip; Section rule; Toast; Sync status.

**Phase 3 — the expensive objects.** Plate (needs the server bake), RankedBarList, TrendChart + Frame + Legend + Scrub, Sparkline, ScoreHero + BandScale + DimensionBreakdown, TableTwin, Progress bar, Person row, Reconciliation line.

**Screen migration, one feature folder at a time behind a green suite.** Agent: Today → check-in states → visit hub → stock counter (needs the null-count answer) → other sections → submit gate → outcome → My work. Manager: The Floor → Alerts/Tasks → Territories → scorecard → fraud queue/case (needs the verdict endpoint) → reports. Assistant last, because it needs the provenance schema to be more than Phase 0. Day goldens follow per component ~~; Veld is sequenced last, once Night and Day components have stopped moving~~ — **struck 28 September 2026: there is no third skin to sequence.** GlassPane is deleted when its 61 call sites are empty, not first.

---

## 6. Open questions for the owner

1. **The Night nav pill costs the plate its light on one screen.** On a tabbed Night route with both a plate and a primary (agent outlet detail with "Check in here"), the plate renders unlit. *Recommend: accept.* Agents default to Day, where the plate is unlit anyway; the alternative — chrome that changes colour per route — reads as a bug.
2. **The pill's attribution risk.** The spec cut the 999-radius active pill as the most recognisable borrowed gesture; decision 3 reinstated it. The contrast objection is fixed (10.65:1). *Recommend: keep the pill; the 3dp underbar is a one-line change in the nav if legal advises it, and nothing else moves.*
3. **Onest + JetBrains Mono: two specimens before goldens.** (a) "R 1,28 mln" at JBM 72 on a 360dp phone — it may not fit; (b) four mono runs inside an Onest sentence, printed and read outdoors at 40% backlight. *Recommend: run both this week; if (a) fails, hero.figure.compact 56 becomes the phone default; if (b) fails, relax the rule to figures in a data role only, leaving years and ordinals in Onest.* Also delete the Archivo paragraph from the spec.
4. **Rating band names.** The wire says green/amber/red; the system cannot have a severity named Amber. *Recommend: client-side map to Healthy / Watch / Gap with six translated strings now; wire migration later; confirm with each client's published banding.*
5. **Null stock counts.** An uncounted SKU must send null, not zero, or a part-counted save accuses a store eight times. *Recommend: schedule the server change before the stock section is built; the two-step "record 8 as out of stock" fallback ships only if it slips.*
6. **The section denominator.** Code says 7 capturable (+1 template); the brief says 9. *Recommend: the agent-facing figure is `captureCount` (outletInfo excluded — it is completed by checking in); the hub lists the capturable rows plus the non-tappable score row.*
7. **One backend migration ticket** for every field the design assumes and the wire lacks: `decimals`, `sampleSize`, `baselineSampleSize`; figure `origin/readAt/publisher` and an outside flag on inline runs; `focus{artifactId,index}` and a `notice` reason on the answer; a server-stamped provisional score; `POST /fraud/visits/:id/verdict` with a lock; a resumed-visit marker; decoded payload size on enqueue; a null-tolerant stock count. *Recommend: one ticket, one owner, sequenced before Phase 3.*
8. **Phase 2 camera.** Without it, capture is the OS camera behind a reminder card and the torch trigger is a worse heuristic. *Recommend: fund it; ship Phase 1 first and review Phase 2 as a separate item.*
9. **Power-save channel.** ~40 lines per platform. *Recommend: schedule it in Phase 0 or delete "battery saver" from every sentence in the design.*
10. **Ask TradeIQ for agents?** *Recommend: manager-only for the first release; a smoke test rather than a full golden set for that surface.* ~~(A Veld smoke test.)~~
11. **Which three tiles on the phone dashboard.** *Recommend: on-shelf availability, coverage, open critical alerts; everything else in the table twin.*
12. **Manager nav: Territories in the Menu.** Floor · Work · Ask · Menu, with Alerts and Tasks merged behind Work and separated by the filter rail. *Recommend: yes; revisit with usage data.*
13. **Per-user UI preferences.** Handedness and the collapsed plate need one ~~, and so did Veld memory~~. *Recommend: add a small per-user prefs table now — two features are waiting on it.* **28 September 2026:** the skin cycle is session-scoped and unpersisted, as it always was, so no stored preference names a skin at all; nothing in the app can read back a `"veld"` that was never written.
14. **The three empty-state drawings** (shelf, pin, envelope) ~~do not exist~~. *Recommend: commission half a day of one illustrator before Phase 2; the enum refuses a stock import.* **29 September 2026:** they are drawn, in `MarkShape`'s idiom one step larger — an outline at 2dp with exactly one solid part, drawn paths only. The dashed placeholder frame is gone from every empty state in the app and `state_test.dart` counts the pixels so it cannot come back. The enum is still closed at three and no call site changed. What is still open under **#404** is only whether an illustrator's hand is wanted on top of these; a stock import remains refused.
15. **Data-layer amber beyond the answer route.** Figures wanted it once in the product; the ladder lets the Territories list light its worst bar. *Recommend: let the ladder decide — the law is per screen.*
16. **Person rows never show photos** (POPIA, bundle size). *Recommend: confirm; if a photo is ever wanted it is a scorecard-only feature behind consent.*
17. **Diverging axis in ink, not amber**, and the meter tick in ink everywhere — both override the spec's written text. *Recommend: confirm both; each is one token in one painter if reversed.*