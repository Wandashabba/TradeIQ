# Torchlight Aisle — the design specification

The source documents behind `docs/design/torchlight-aisle.md`. That file is the
engineer's guide to the **landed** APIs; these are the design decisions the
APIs implement. Read them before migrating a screen.

| File | What it is |
|---|---|
| `unify.md` | **The coherence ruling. Authoritative.** Where five surface designs disagreed, it rules on every contradiction, lists the canonical components, the cross-cutting rules (amber, non-colour encoding, 2.0× text, ~~Veld~~, paint budget, unknown vs zero) and the build order. It wins over everything else here. |
| `surface-kit.json` | The component kit: surfaces, rows, buttons, inputs, chips, sheets, nav, states. |
| `surface-figures.json` | Figures and data visuals: stat tiles, ranked bars, trend charts, the score hero, unknown-vs-zero. |
| `surface-agent.json` | The field agent's screens: route, check-in, visit hub, sections, capture, outcome, outbox, the agent's record. |
| `surface-manager.json` | The manager's console: The Floor, alerts, tasks, territories, scorecards, fraud review, reports. |
| `surface-assistant.json` | Ask TradeIQ: composer, working steps, streaming answer, figures, sources, every error state. |
| `direction-torchlight.json` | The original direction the owner chose, before the surfaces were designed. |

Each surface file is a JSON object with an `items` array; every item carries
`anatomy`, `states`, `behaviour`, `modes`, `accessibility`, `amber` and
`screenshot`. Search by item `name`.

## The surface JSON is an archive, and it still describes Veld

**Owner decision, 28 September 2026: VELD IS REMOVED FROM THE PRODUCT.** Veld
was the third skin — white ground, near-black ink, radius 0, 2px borders,
nothing under 9:1, sheets as full-screen routes, the nav docked, and no chart,
map or plate at all. It existed so a **field agent could read this app in
direct sunlight**, and **that is what has been given up**: an agent in a
forecourt at 13:00 now reads Day, and nothing replaces the outdoor skin.

The five `surface-*.json` files and `direction-torchlight.json` below are the
**design inputs**, committed as a record of what each designer proposed before
the coherence pass ruled on them. They are not edited when a ruling changes —
that is the point of keeping them — so **their `modes` fields still describe
Veld**, and so does `direction-torchlight.json`. Read them as history. The
live rules are in `unify.md` §4 and `../torchlight-aisle.md`, both of which
carry the decision struck through beside the text it replaced, and the code is
the final authority over both.

## Two owner decisions override these documents
- **The typeface is Schibsted Grotesk** (Onest until 1 October 2026; never
  Archivo) for all prose. **JetBrains Mono** sets
  every figure in a data role and every machine identifier.
- **The navigation is a floating pill** with a solid amber active tab and a
  separate circle for the primary action.

These were produced by a design workflow (five designers, a critic per surface,
a revision pass, and a coherence pass) and committed here so they are versioned
alongside the code that implements them.
