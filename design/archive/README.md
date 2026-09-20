# The pre-Torchlight mockups

Seventeen files — fifteen HTML screens, `tokens.css` and `agent.css` — that
were the design of TradeIQ before the Torchlight Aisle. They are kept because
they are the record of what the product looked like and why, and because the
reasoning in their comments (the agent layer's thumb-zone argument, the
palette's CVD validation notes) is still worth reading.

**They are history, not instruction. Do not build from them.** They describe a
palette and a typeface the app no longer ships, and on several points they say
the opposite of what the code now does.

## Superseded on 2026-09-18

Torchlight landed in `943572a1`, *"feat(theme): Torchlight Aisle — one token
source, three skins, and guards"*. The specification behind it was committed
the following day in `49b8c0e5`. These files were last edited on 2026-07-30
and have not tracked the app since.

## The palette they use

`tokens.css` is the **flat dark instrument panel** — one theme, cool greys,
a blue brand, and a three-step status ramp:

| | Mockups (`tokens.css`) | Shipped (Torchlight) |
|---|---|---|
| Ground | `--plane #0b0c10`, `--surface-1 #14161c` | `ground #0B1017` warm-inked navy-black, plus Day `#EEE9DF` and Veld `#FFFFFF` |
| Brand | `--brand #0a6cf0` — a blue, used for identity *and* interactive affordances | `flame600 #FFB162` — a single amber that is **emitted light, never a label** |
| Series | fixed categorical `#3987e5` / `#199e70` / `#c98500` | one amber focus fill per chart, `chartNeutral #A39887` for every other bar, `comparison` for "them" |
| Status | `--good #0ca30c` / `--warn #fab219` / `--crit #d03b3b` | `good` / `bad` at two commitment levels. **There is no `warn` token**, and severity abandons amber's hue band entirely |
| Type | `--font: 'Inter', …` | Onest for prose, JetBrains Mono for every figure and identifier |
| Themes | one | three skins — Night, Day, Veld — and two densities |

The two biggest contradictions are worth naming, because someone skimming a
mockup will reach for them:

1. **Amber is a status colour here and a light source in the app.** `--warn
   #fab219` is the mockups' "warning". Torchlight has no warning colour at
   all: amber tells you where to look and never how bad something is, and the
   whole 25–45° band is reserved for the brand.
2. **Inter is gone.** It is not merely unused —
   `app/test/core/theme/torchlight/torchlight_type_test.dart` fails if Inter
   creeps back into the bundle.

## What is authoritative now

- **`docs/design/spec/`** — the source of truth. `unify.md` is the coherence
  ruling and wins over everything else; the five `surface-*.json` files are
  the component designs it reconciles.
- **`docs/design/torchlight-aisle.md`** — the engineer's guide to the landed
  APIs. Where it and the code disagree, the code is right.
- **`app/lib/core/theme/torchlight/`** — the tokens themselves, with the
  guards in `app/test/core/theme/torchlight/` recomputing every declared
  contrast pairing on each run.

## Notes

- The whole set moved together, so the relative links between the screens and
  to `tokens.css` / `agent.css` still resolve. Open `index.html` from this
  folder as before.
- `design/videos/` was deliberately left where it is. It is not part of this
  archive.
- `app/lib/core/theme/app_colors.dart` still says it mirrors `tokens.css`;
  its doc comment now points here. That file is itself `@Deprecated` and goes
  when the last four Lumen screens are migrated.
