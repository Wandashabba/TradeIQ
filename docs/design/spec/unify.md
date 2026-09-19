# TradeIQ · Torchlight Aisle — One System

Five surfaces (kit, figures, agent, manager, assistant) reconciled against `refine-cinematic.json` and the owner's five standing decisions. Where the spec and an owner decision disagree, the owner decision wins (typeface: Onest + JetBrains Mono; nav: floating pill with a solid amber active tab and a separate circle). Where two designers disagree, one is picked below and the reason is one sentence.

---

## 1. Contradictions — rulings

### 1.1 The amber budget and how it is counted
| Surface | Said |
|---|---|
| Kit | TorchScope: 2 grants Night, 1 Day/Veld; nav active tab is a *reserved chrome grant* in Night; content gets 1 grant on tabbed routes, 2 untabbed. Ladder: primary → plate → chart focus → nav circle → live pulse → meter tick. |
| Figures | AmberLedger: 2 per screen, chrome counted, resolved statically per phase; data-layer amber exactly once in the product. |
| Agent | Composed-frame lint: 2 Night, 1 Day/Veld; nav pill is object #1 on tab roots; allows an amber target tick on Outcome, the reward bar and the stat tile. |
| Manager | TiqLedger: nav active slot **exempt**, one content nomination. |
| Assistant | 2 counted, nothing exempt; nav is a 3dp **underbar**; the pill **retracts on scroll**. |

**Ruling — Kit's TorchScope is the mechanism, Figures' static resolution is how it runs, and the arithmetic every surface actually lands on is the same:** Night = the nav's amber tab (when the nav renders) + one content object on a tabbed route; two content objects on an untabbed route (inside a visit, a sheet, a full-screen state); Day/Veld = one, the primary commit block. The nav is *counted* as slot 1 (manager's "exempt" and kit's "reserved" produce the same number; "counted" is the honest word). The claim set is computed by the route's view model at construction and per declared phase (figures), never per frame, so a grant can never blink. The assistant's underbar becomes the pill (owner decision 3); the assistant's scroll-retracting nav is rejected — kit and manager both forbid chrome that changes on scroll, and a slot that came and went with a thumb would make the count flicker.

**Meter target tick: ink-1 everywhere. `TorchClaim.meterTick` is deleted from the ladder.** Figures and manager win over kit and agent: a target is an annotation, an annotation is a label, and the tick's silhouette (breaking the track's top edge) is what carries it. Agent's Outcome drops to 1 amber (Next store), What I've earned to 0, the agent stat tile to 0.

**Live pulse means presence, never progress.** Kit gave the outbox row and the held banner a `livePulse` claim; agent said sending motion is Oatmeal dots. Agent wins: the pulse is reserved for a human mid-visit (person row, day trail), a tool executing (Ask), and a GPS fix being sought (check-in locating). Uploads are progress, and progress is a report.

**Text-field focus rule (2px flame-700) is counted, not exempt.** Kit exempted it; agent counted it; assistant cut it. Keep it and count it: it fits because the keyboard hides the nav (kit's own keyboard-open rule), returning that grant to content, so a focused field plus a lit primary is exactly two. The D-pad/keyboard focus ring stays exempt (it never co-occurs and never appears for touch users).

**Diverging chart axis is never amber** (assistant over figures/spec): a 1dp ink-1 axis at 15:1 is more visible than amber, and amber there would displace the focus row for no legibility gain.

**Data-layer amber is allowed wherever the ladder grants it, not "once in the product" (kit over figures):** the Territories list may light its worst bar; the dashboard cannot because the plate takes the grant. Figures' "exactly once" was a consequence of its ledger, not the law.

### 1.2 Navigation geometry
- **Bar:** radius 999, 64 tall, inset 16, 20 above safe area, `well` fully opaque, 1px edge-structure outline (kit). Agent/manager/assistant's radius-14 bars lose to owner decision 3.
- **Active tab:** solid flame-600 pill, radius 999, 48 tall, inset 6, ink `#0B1017` (kit). Day/Veld: solid Abyssal block, ink Palladian/white — never amber.
- **Slots: four maximum** (kit's 360dp arithmetic). Manager: **Floor · Work · Ask · Menu**; Territories move into Menu under OPERATE. Agent: Today · My work · Map · Me.
- **Circle: 64dp**, outside the bar, 12dp gap (kit; manager's 56 loses because it is the primary action and 56 is the Veld floor).
- **Skin cycle is not on the nav row.** Agent put a 56dp skin cycle beside the pill; at 360dp that leaves 192dp for four slots. Ruling: on tab roots the skin cycle is the app header's single trailing icon button (kit's header allows exactly one; assistant already put it there); on every other agent screen it sits at the leading end of the thumb zone (agent).
- **Large text:** the bar measures every localised label with a `TextPainter` and goes icon-only as a whole (kit). Agent's 76dp bar and 2×2 grid at ≥1.6× lose — a 132dp nav grid plus a circle plus a thumb zone is a third of a 640dp screen.
- **Veld docks the nav** — full-bleed, 72dp, 2px top border, radius 0 (manager): a white pill floating on white under glare stops reading as a bar, and Veld has no radius but 0.

### 1.3 Rows — separation, height, fill
| Surface | Row boundary in Night |
|---|---|
| Kit | 1px edge-structure outline on every row, radius 14, 8dp gaps |
| Agent | flush, radius 0, 1px rule inset to the text edge — edge-structure between tappable rows, hairline between non-tappable |
| Manager | no line, no radius, 12dp ground gap, optional hairline seam |
| Assistant | 20dp clear space + hairline-decorative |

**Ruling — one component, two forms.** **List rows** are flush, radius 0, separated by a 1px rule inset to the text edge: edge-structure (3.73:1) between tappable rows, hairline-decorative between non-tappable (agent). **Standalone rows** (Next-up, day block, readiness block, outbox summary) are radius 14, `surface` fill, 1px edge-structure outline (kit). Manager's gap-only rows fail the device floor (a 12dp gap between two 1.12:1 fills is the circular argument kit already killed); kit's outline-per-row in a list is the "uniform rounded cards" anti-slop failure and closer to a hard box than owner decision 2 allows. Manager's 3px severity bar and its "content starts at 35dp whether or not a bar is present" alignment rule survive.

**Heights — kit's three densities win:** compact 56 (Console lists), standard 64 (Field lists), tall 80 (two meta lines: Next-up, outbox, person, decision rows — manager's 76 rounds up). Tappable targets are ≥48 everywhere; manager's 44dp tappable rows and assistant's 48 both map to compact 56.

**Pressed row (Night):** fill → lifted **and** the row's rule/outline steps to 2px edge-control, plus scale 0.98 and `Buzz.tick`. Manager's 3px leading tick at x=0 is rejected — it collides with the severity bar's position vocabulary and Veld's 2px border — but its complaint (lifted-on-well is 1.49:1) is answered by the edge step.

### 1.4 Stat tile
- **Phone layout is horizontal** (figures): eyebrow `Expanded` left, figure right-aligned, meter beneath, delta beneath. Single column below 320dp inner width — which is every phone. Assistant's 272dp threshold (2×2 at 138dp cells) loses on its own arithmetic: "R 1,28 mln" at JBM 32 is ~192dp.
- **Cell separation:** 12dp gap with a centred 1px edge-structure rule in Night, hairline in Day (assistant's tier-2). Figures/agent's hairline-only loses (1.72:1 is invisible); manager's no-line loses (the grid is the instrument reading).
- **Eyebrow:** uppercase, 11/700, tracking **+4%**, wraps to 2 lines (manager). Applies to the eyebrow role globally.
- **`chart-neutral` moves to #A39887 Night / #5C5648 Day** (figures) — the old value sat at 3.01:1 and the Day value was byte-identical to ink-3. Kit, agent and manager update.
- **Count on phone:** 4 max, 3 recommended (figures).
- **Manager's "lead indicator"** is a StatTile variant (`lead: true`), not a component.

### 1.5 Section state glyph and "can't confirm"
- **Can't confirm is a fourth silhouette, not a hatch** (figures over kit, agent and manager): a ring at the empty ring's stroke with a 2px diagonal bar. A 3dp stripe inside a 28dp tile aliases to a flat grey disc at 40% backlight — the half-circle it must not resemble. **No pattern inside any glyph or on any mark under 4dp** (hatch registry). Manager's 12px hatched "not measured" square becomes a barred square.
- **In progress** = a half-disc glyph inside the tile (agent) — kit's half-filled tile is 1.49:1 on the well.
- **The 2px vertical ladder rule is deleted** (agent): rows now carry their own 3:1 rules and a line crossing them is decoration.
- **Meaning-bearing glyphs scale with text** (agent): tile 28→48, glyph 16→32, delta triangle 8→16, chips' glyphs 16→32. Kit's fixed sizes lose.

### 1.6 Chips
- **Flag chips are never crimson** (kit + agent over manager). Out of fence and flagged for review are facts, not verdicts. The single severity flag is **Sent back** (a human rejected the work).
- **One neutral treatment:** fill well, 1px edge-control, glyph + word; visual height 28 inline / 32 Field / 40 Veld inside a 48dp hit box when tappable (manager's box-in-hit-area). Label 11/700 Console, 13/600 Field, 16/600 Veld, sentence case.
- **Selected filter chip** = lifted fill + 1px ink-1 border + tick + weight 700 (kit, three channels) — manager's edge-control-stays loses. Never amber, on any screen (spec's amber selected edge is overruled by all five).
- **Follow-up chips** = the filter chip component, 48 tall.

### 1.7 Buttons
- **Primary label:** 16/600 Field, 14/600 Console, 18/700 Veld (agent's argument — the commit action was carrying the smallest type on the screen).
- **Night press:** floods to flame-500 with `#0B1017` ink (kit) — one ramp step darker than the Day block so all skins press to the same colour; agent's flame-600 flood loses only on that consistency.
- **Rim + 2dp top bleed is one object** (kit) — the assistant's cut of Send's bleed is reversed.
- **Dialog is deleted.** A non-dismissible bottom sheet (agent's session-ended first appearance) covers every blocking case; one modal container.

### 1.8 Count stepper
Agent's layout wins: value trough leading, an adjacent [−][+] pair trailing (56×56 each, 1px rule between), mirrored by a handedness preference. Typing opens a number sheet with Cancel/Set — a stray tap cannot replace a count, which was kit's whole worry. Kit's null→minus records 0, null→plus records 1, and whole-control finding treatment stay.

### 1.9 Checkbox / choice row / toggle
Checkbox 28dp (agent; 48 at 2.0×), kit's mixed state stays deleted. Choice options radius 6 (the chip material), selected = lifted + tick + weight 700 — one selected vocabulary across chips. Toggle 52×32, thumb 26 with a tick inside, and the state word is mandatory.

### 1.10 Bottom sheet
- **Scrim 72%** (kit/agent/manager/spec) — the assistant's 88% defeats #380's "held work visible behind it". The assistant's real finding is honoured a different way: **while a sheet is up, every amber on the route beneath goes out** (the nav tab drops to its ink form, the plate's light goes off), so the sheet's TorchScope genuinely owns the screen.
- Grabber `#616465` declared hex (kit's opacity ban), max height 88%, horizontal padding = gutter, 16 below the grabber, 24 + safe area at the bottom. No stacking; a sheet that needs a sheet cross-fades its own content (kit + agent agree).
- **Veld has no sheets and no scrims** (assistant): they become full-screen white routes with a 2px border and a 56dp Close row.

### 1.11 Skeleton
Kit wins on colour: Night text-line blocks are **edge-structure fill** (3.33:1), rows and panels are their real outline at their real geometry, empty. The other four surfaces' `well` blocks are 1.12:1 — the thing the device floor forbids. The 1400ms Oatmeal travelling rule after 600ms stays (assistant's deletion loses: an 8s stall with nothing moving reads as frozen).

### 1.12 Empty state
Whole-screen: 64dp drawing from the **closed enum of three** (shelf / pin / envelope — agent's "map, shelf, box" and assistant's shelf map onto it) + display 40 with the agent's **line-count fitting rule** (1–2 lines 40, 3 lines 32, 4+ 26). In-panel or inline: no drawing, title.m/title.l headline (manager, figures). Manager's "no illustration anywhere" loses for whole-screen — the enum cannot drift and needs half a day of one illustrator.

### 1.13 Held / offline / stale colour
Held is **Oatmeal (ink-2) square on the well** — kit, figures, agent, spec. Manager and assistant used the Truffle `comparison` square for held, offline, session-ended and "incomplete". Truffle is the comparison series ("them, unlit") and nothing else; giving it a second meaning is exactly the failure the severity system avoids.

### 1.14 Sync chip vs held banner
Kit promoted the sync chip into a 56dp banner under every agent header; agent kept the chip in the header. **One component, two forms:** the chip is the default; the banner form renders only for NEEDS-YOU and OFFLINE-ENTIRELY. A permanent 56dp band on every screen spends the fold the manager surface spent an item defending.

### 1.15 Person row
40dp radius-6 tile, **initials only — never a photo** (agent + assistant, POPIA; kit and manager lose). Name **wraps to two lines**, middle-truncates only when a line is structurally forced (manager/assistant — "Dlamini-Mkhize" vs "Dlamini-Ndlovu"). Id is never the primary line; kit's long-press "Copy id" stays; the unknown state shows the id in mono.ident.

### 1.16 Plate
Kit's **fixed perspective fallback plus a sentence** wins over manager's data-driven spacing (nobody decodes line spacing). Manager wins on **height** (`min(clamp(0.44·vh, 200, 360), vh − 440)`, collapsed 96dp band under 200), **bytes** (lossy WebP + alpha, ≤60 kB — kit's PNG loses), **provenance caption**, and **"Dark frame — mean brightness 11%"** rather than a cause. The Panel's Palladian@10% top rim is **cut** everywhere (assistant; figures measured 1.32:1) — it costs a paint and says nothing.

### 1.17 Figures and type
- **Formatter:** figures' `TiqNumber` and `FigureSlot` (measured fitting incl. affixes, `TextScaler.scale()` not a factor, no `FittedBox` in baseline rows) replace kit's glyph-count table, agent's and assistant's fitting rules.
- **Weights:** figure roles JBM **600**, hero/display **700** (kit's token sheet; figures' 500 loses). **Tracking 0 on every mono role** (figures; kit's −2.5% hero was an Archivo instruction).
- **Mono in prose:** 0.94em of the surrounding role, letterSpacing 0 (assistant); agent's −1% loses to the no-negative-tracking rule.
- **Eyebrow is legal in three places only:** a stat tile's label, a hero/plate figure's label, a block label inside a panel ("WORST FIRST"). Every screen-level section marker — including the assistant's "WHAT EXPLAINS IT", "SOURCES", "TRY ONE OF THESE" — is the knocked-out rule at title.m, sentence case.
- **Trend chart:** 208 Console phone / 232 Field / 180 Veld / 260 at ≥600dp; assistant's 160 loses (with a 38dp gutter it leaves ~120dp of plot). Gridlines `lifted`. Ranked label wraps two lines then middle-truncates (assistant); cap 8 rows.

### 1.18 Progress-to-reward bar
One component: 8dp track (12 at 2.0×), lifted fill + 1px edge-structure outline, `chart-neutral` fill, ink-1 milestone ticks breaking the top edge, the words always beneath. Reached: fill goes `good` and a filled circle sits at the tick (agent/manager); figures' "good after the first milestone" loses — clearing one of three milestones is not a verdict. Never amber (three surfaces over agent).

### 1.19 Meter track
Figures wins: 4dp Console / 6dp Field / 8dp Veld, **outlined only in the empty, null, loading and hatched states** (a filled track needs no edge). Kit's always-outlined 6dp loses.

### 1.20 Provisional / reconciliation
- **The agent app never shows a provisional score** (agent); `visit_outcome_screen.dart`'s no-guess stands. Kit's numeric-field provisional state is deleted.
- **One Reconciliation line component, two string sets:** agent second person ("Now scored 71 — it was 84 when you saw it"), console third person ("Scored 71 — the phone showed 84"). Both figures mono; neutral square glyph; never good/bad.
- **Provisional marker** (dotted underline + word) exists only on the console, only for server-stamped provisional figures.

### 1.21 Decision sheet
Merged: kit's **proof block** (counts in JBM, section-state glyphs leading each line, both actions busy until the count resolves) + agent's **two-step in-sheet confirm** ("Delete and start over", bad-outlined, cross-faded, never a second sheet) + agent's **stale-fix branch** (>12h: "Check in again" is the primary). Kit's undo toast after start-over is dropped — the two-step is the guard. The manager's Confirm sheet and the assistant's Start-over sheet are instances.

### 1.22 Skip-reason picker
Agent's version wins (consequence line under each reason, third-can't-confirm warning, check-in variant with different reasons, saved reason appears on the submit gate) with kit's states folded in (already skipped, no reasons configured, offline held, dismissal is safe).

### 1.23 Icon button toggled-on (torch, skin)
Solid Abyssal block, **ink-1 glyph**, the word ON (agent's Phase 2). Kit's Day/Veld "amber glyph" — inherited from the spec — is overruled: a toggle state is a label. This is the one place the reconciled system corrects the spec's own text.

### 1.24 Session ended
A **bottom sheet** over the live screen (agent/manager), non-dismissible on first appearance, held work visible behind it; kit's full-screen state loses because the sheet delivers the proof block *and* the screen. After "Not now", the 44dp persistent line under every header (agent) — the assistant's composer band is that line.

---

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
4. **MotionBudget** — single `still` boolean (disableAnimations ∨ Veld ∨ powerSave). *New.*
5. **HatchPaint registry** — four patterns (not-measured ↘, negative ↗, low-sample outline, provisional outline+dots); never on a glyph or under 4dp. *New.*
6. **Separation tiers, glyph-scale rule, press/focus/haptics, fold budget, breakpoints** — cross-cutting rules (section 4). *New.*

### B. Chrome
7. **Shell** (Agent / Console) — gutter, header ceiling, scroll frame, bottom region (tab-root row / thumb zone / skin-cycle-only zone). *Replaces* Scaffold+AppBar usage.
8. **App header** — title, capped subtitle, one trailing icon button, flag-chip wrap with expander. *Replaces* AppBar.
9. **Nav pill** — four slots, amber active pill in Night, measured labels, docked in Veld. *Replaces* the bottom nav.
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
20. **Bottom sheet** — 72% scrim, no blur, no stacking, full-screen route in Veld. *Replaces* showModalBottomSheet styling.
21. **Decision sheet** — proof block + resume / start-over / confirm-destructive. *New (#374).*
22. **Skip-reason picker** — reasons with consequences, check-in variant. *New (#395).*
23. **Session-ended sheet** — a state, held work behind it; persistent line afterwards. *New (#380/#392).*
24. **Skeleton** — real outlines and edge-structure text blocks; Oatmeal rule after 600ms. *Replaces* CircularProgressIndicator.
25. **Empty state** — whole-screen (closed enum drawing + display) / inline. *Replaces* centred "No data".
26. **Error state** — whole-screen / inline; one Retry per region; sanitised messages. *Replaces* raw error text.
27. **Pagination footer** — "Showing the 20 riskiest of 74" + unscored note. *New.*

### D. Controls
28. **Primary button** — commit; rim + bleed Night, block Day/Veld; BarNote when disabled. *Replaces* ElevatedButton.
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

**Amber.** Burning Flame is emitted light, never a label. Night: at most two amber objects in the composed frame, counted — the nav's active pill is object 1 whenever the nav renders; content has one grant on a tabbed route and two on an untabbed one (in-visit, sheet, full-screen state). Day/Veld: exactly one, the primary commit block, and zero when nothing is armed. Precedence: primary commit → plate strip light → chart focus (one bar or one series) → nav circle (only on a route with no primary) → live pulse (one per route, presence only). A route may declare one `subject` override. The text-field focus rule counts and fits because the keyboard hides the nav. Amber is never: a chip, flag, status, badge, tick, divider, gridline, axis, toggle, toast, skeleton, sparkline, delta, empty state, icon tint, section marker, word, or anything repeated. Tokens: flame-600 (light), flame-500 (pressed), flame-700 (focus rule), flame-bloom `#FFF1DE` (gradient stop); no others exist. Enforced three ways: TorchScope asserts on over-claim; a pixel golden connected-components every flame-hued region per route × phase × skin and fails above the budget; a lint forbids `flame*` outside an allowlist of emitter widgets. While a modal sheet is up, every amber beneath it is extinguished.

**Non-colour encoding.** Every hue-coded distinction carries a second channel — shape, weight, dash, hatch, outline, or a word — and the second channel is the one that must survive greyscale, deuteranopia, glare and a screen reader. Severity is crimson at two commitment levels (outline = Watch, solid = Critical) + silhouette + word; there is no amber warning. Held is Oatmeal + square + word; Truffle is the comparison series and nothing else. Selection is fill + weight + mark. Nothing is identified by a fill step alone in Night: anything with a perceivable boundary carries a real edge (edge-structure 3:1 for containers, edge-control for controls). Opacity is banned as a state channel; composited values are declared hexes. Every meaningful glyph has a `semanticLabel` bound in the same token as its hue.

**2.0× text.** `textScaler` clamps at 2.0 (hero.figure at 1.6, applied to `TextScaler.scale()`, never a factor). Meaning-bearing glyphs scale with it (tile 28→48, triangle 8→16, chip glyph 16→32); decorative marks stay fixed; tracks scale at half rate. Every label wraps to two lines at every size; nothing is pinned; outlet names middle-truncate before status words. Nav labels are measured and go icon-only as a whole. Tile grids collapse on `LayoutBuilder` width, never on a text-scale guess. Headers cap at 40% of the viewport, then scroll. Sheets never resize under a thumb. Afrikaans: a pseudo-localisation CI pass renders every label at 1.4× width and fails on overflow.

**Veld.** A third theme, single density, white ground, `#0E141A` ink, nothing under 9:1 for text or 15:1 for borders; every hairline a 2px `#1B2632` border; every shadow, gradient, rim, bloom, scrim and blur removed, not softened; sheets become full-screen routes; the nav docks. Type steps by declared members (body 17, label 16, meta 14, title.m 18, figure.m 24), 600 weight floor. Targets 56, rows 64, gutter 24, block gap 40. One amber block, the primary, ink `#0E141A` on it. Entered by the skin cycle, by solar elevation on a state change, or by memory; never auto-expires. Motion off. The plate, sparklines, trend charts, maps and thumbnails do not render; figure lists replace them.

**Blur / shadow / paint budget.** Zero `BackdropFilter`, `ShaderMask`, `ImageFiltered`, `saveLayer`. Night: zero `BoxShadow`; Day: sh1/sh2/sh3, ≤6 per screen. Every bloom is a `LinearGradient` in the existing draw call; ≤12 gradient decorations per screen, none inside a `ListView.builder` row (hatches are painter lines there). One app-wide `Ticker`, three subscribers. Plates are baked server-side (12% chroma, `#474747` ceiling, alpha dissolve, ≤60 kB WebP) and decoded at `cacheWidth`. Sparklines cache to a `Picture` in a `RepaintBoundary`. A profile test fails the build at p95 raster > 12 ms on the dashboard and answer routes.

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

**Screen migration, one feature folder at a time behind a green suite.** Agent: Today → check-in states → visit hub → stock counter (needs the null-count answer) → other sections → submit gate → outcome → My work. Manager: The Floor → Alerts/Tasks → Territories → scorecard → fraud queue/case (needs the verdict endpoint) → reports. Assistant last, because it needs the provenance schema to be more than Phase 0. Day goldens follow per component; Veld is sequenced last, once Night and Day components have stopped moving. GlassPane is deleted when its 61 call sites are empty, not first.

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
10. **Ask TradeIQ for agents?** *Recommend: manager-only for the first release; a Veld smoke test rather than a full golden set for that surface.*
11. **Which three tiles on the phone dashboard.** *Recommend: on-shelf availability, coverage, open critical alerts; everything else in the table twin.*
12. **Manager nav: Territories in the Menu.** Floor · Work · Ask · Menu, with Alerts and Tasks merged behind Work and separated by the filter rail. *Recommend: yes; revisit with usage data.*
13. **Per-user UI preferences.** Handedness, the collapsed plate and Veld memory all need one. *Recommend: add a small per-user prefs table now — three features are waiting on it.*
14. **The three empty-state drawings** (shelf, pin, envelope) do not exist. *Recommend: commission half a day of one illustrator before Phase 2; the enum refuses a stock import.*
15. **Data-layer amber beyond the answer route.** Figures wanted it once in the product; the ladder lets the Territories list light its worst bar. *Recommend: let the ladder decide — the law is per screen.*
16. **Person rows never show photos** (POPIA, bundle size). *Recommend: confirm; if a photo is ever wanted it is a scorecard-only feature behind consent.*
17. **Diverging axis in ink, not amber**, and the meter tick in ink everywhere — both override the spec's written text. *Recommend: confirm both; each is one token in one painter if reversed.*