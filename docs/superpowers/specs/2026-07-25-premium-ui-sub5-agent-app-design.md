# Premium UI Sub-project 5 — Field-Agent App Design

**Date:** 2026-07-25
**Status:** Design approved (brainstorm); pending spec review → writing-plans.
**Predecessors:** Sub-1–4 (manager console premium redesign, merged/in-flight). This is the field-agent counterpart.

## Context

TradeIQ's Flutter app (`app/`) serves two distinct experiences: the **manager console** (redesigned in sub-1–4 to a light Stripe-premium system) and the **field-agent app** — what a sales rep uses in-store to run a visit. The agent app is phone-first, offline-first (Drift/SQLite outbox + best-effort sync), and today lives behind its own scaffold (`AgentScaffold`, currently `PinnedDark`) and its own widget kit (`agent_kit.dart`), separate from the console's `console.dart`/`worklist.dart` system.

The agent app was **never** touched by the premium redesign. Its state is uneven: the landing (`today_screen`), visit hub (`audit_shell_screen`), my-work, submit gate, and outcome screens were built on the kit with motion; but the **outlet picker and capture sections S1, S6–S9 are raw Material** (`Card`/`TextField`/`DropdownButtonFormField`/`SwitchListTile`) — the "AI-template" baseline this whole redesign exists to remove.

## The decision (what this sub-project is)

**Bring the field-agent app onto the manager console's design system**, so the two halves of the product read as one. This is a *premium redesign* (fill the raw-Material gaps AND raise the whole app), not just a consistency pass.

**Key direction call (brainstorm):** the agent app adopts the **console's design system** — glass hero, `PanelCard` cards, `DeltaPill`/status pills, worklist-style rows with coloured left edges, `#0A6CF0` accent, `radiusPanel`/`radiusPill`, the static Stripe shadow, the dataviz rules — **not** a bespoke "glowy/luminous" language (an earlier direction, dropped).

**Theme:** **interchangeable light + dark — both first-class.** The agent app moves off `PinnedDark` and becomes **theme-aware**, using the console's dual-theme tokens (which already define both light and dark). A rep can switch — light for a bright shopfront, dark for a dim aisle / battery. Both themes are designed, tested, and screenshotted; neither is a "flip later" afterthought.

**Unchanged:** all providers, repositories, the Drift offline outbox, geofence/check-in logic, the sync engine, photo downscale/8MB cap/base64 pipeline, and the backend. This is a **presentation + camera-overlay** redesign. No data-model or API changes.

## Design language (inherited from the console)

Reuse the console's tokens and shared widgets directly wherever they fit — do **not** fork a parallel visual system:

- **Ground / surfaces:** `plane` app background, `surface1` cards, `line` hairlines, `radiusPanel = 12`, the static Stripe shadow (`Color(0x0D14161C)`, blur 2, offset (0,1)).
- **Glass hero:** `heroWash → surface1` gradient, `heroBorder` — the execution-score hero pattern, reused for the agent's headline moments (route progress, visit progress, score reveal).
- **Pills:** `DeltaPill` (`▲/▼/–` + good/warn/bad washes) for deltas; the console's pill treatment (rounded `radiusPill`, solid-brand active) for filters/segments; a small status pill for section state and sync state — **always words + glyph, never colour alone**.
- **Rows:** the sub-4 worklist card (surface1 + hairline + `radiusPanel`, coloured severity **left edge**, optional thumb slot) for route stops, section rows, and my-work items.
- **Accent:** `#0A6CF0`, constant across themes.
- **Type:** console ink tokens (`ink1/ink2/ink3`), Inter static weights (400/500/600/700).
- **Dataviz:** the score/progress marks follow the console's dataviz rules (one axis, thin marks, text in ink tokens, status colour only with labels).

The agent app keeps a thin **phone-ergonomics layer** on top of this system (see Architecture): thumb-zone primary button, 48px `kTapTarget`, `CountStepper`, the guided camera. Those primitives get **restyled to console tokens**; they do not carry a separate look.

## Screens

Every screen adopts the console light system. Behaviour/routing unchanged.

1. **Today (landing).** Header (date + "Today"); a **glass hero** for route progress (big `4/9`, delta/"on pace" pill, thin progress bar — the execution-score hero pattern); route stops as worklist cards (green left-edge = done + score, brand left-edge + "NEXT" pill = next stop, muted = upcoming, distance in ink3); pinned primary "Start next visit"; secondary "Visit a store off my route".
2. **Outlet picker** *(raw Material today → rebuilt).* Search + territory-scope control as console pill/segment; outlet rows as worklist cards; pinned "Start visit".
3. **Visit hub / check-in.** The **arrival moment**: geofence states — checking-in (a transient radar/progress indicator), **checked-in** (green status card with the **honest distance**, e.g. "Checked in · 32 m"), **too-far** (honest distance + fraud note, existing behaviour, restyled), no-location. Then a **glass hero** for visit progress (sections done / total) and worklist-style **section rows**: done (green edge + ✓ + "Done"), active (brand edge + "›"), optional (muted + "Optional"), blocking-required (amber edge + word). Pinned "Review & submit" (gated by existing `canSubmit`).
4. **The 10 capture sections — unified on the system.** All sections rebuilt on console-tokened kit primitives; **no raw Material remains**:
   - S1 Outlet info, S6 Competitive, S7 Capability, S8 Risks, S9 Action plan — currently raw; rebuilt (fields, selects, toggles, entry rows → console-tokened primitives).
   - S2 Stock — `CountStepper` restyled (zero-is-a-finding preserved).
   - S3/4 Visibility, S5 Pricing — restyled + the blended capture (below).
   - S10 Score — computed, shown in the hub (not openable), as a glass stat.
5. **Capture (blended).** Inline capture tile in the section (console card, tappable) → tap opens a **full-screen guided camera** (section name, framing hint, framing brackets, thumb-zone shutter, gallery fallback) → **keep/retake review** → back inline. Downscale (maxWidth 1600, q80), 8MB cap, base64 data URL, and **offline enqueue** (`DriftQueuedPhotosRepository`) all preserved. Evidence photos are real captures — never generated/placeholder art (honesty).
6. **Submit gate.** Console review layout: captured summary, "this will raise N tasks," blocking items called out, primary "Submit."
7. **Outcome / score reveal.** The **glass hero score moment**: the execution score counts up (~600ms, one-shot) as a large figure in a glass card, a **`DeltaPill` vs the last visit**, and an **honest sync line** — "Sent · nothing waiting," or **"Saved on phone"** when offline (a receipt, never an error). Primary "Next store."
8. **My-work / sync queue.** Worklist cards for pending / needs-attention / sent, honest counts, retry affordances — the trust surface.

## Offline trust (load-bearing honesty)

Everything the agent captures is written locally first (Drift outbox) and synced best-effort. **Every surface must tell the truth about sync state** — the sync chip (pending count), the outcome ("Saved on phone" when offline), the my-work queue (waiting / failed / sent, with retry). **Never imply "sent" when data is only local.** This behaviour exists today; the redesign preserves it exactly and only makes it legible in the console language.

## Motion (console discipline)

- **One-shot entrances** (reuse the existing `Reveal`) on lists/sections; console's one-shot count-ups for progress/score (~600ms, reduceMotion → final value on first frame).
- **Transient** check-in radar (only while checking in — not a perpetual loop).
- **No perpetual loops** in the console language (the glowy breathing from the dropped luminous direction is out). The only sanctioned loop in the product remains the maps' pin-glow (manager side), unchanged.
- Haptics preserved (`Buzz.tick/finding/done`). `reduceMotion` → fully static except content.

## Accessibility & honesty (carry-forward, non-negotiable)

- State never by colour alone — status rows carry glyph + word (done ✓ / active › / optional / blocking).
- Geofence distance always shown honestly (check-in and too-far).
- Sync state always truthful; no fabricated data; evidence photos are real captures.
- Every new pill/card text pair clears **4.5:1** on its ground (light tokens are pre-validated; verify in review).
- `kTapTarget = 48` preserved; primary action in the thumb zone.
- `reduceMotion` yields a fully static UI except content.

## Architecture

- **Adopt console shared widgets** (`PanelCard`, `DeltaPill`, the worklist card, pill/segment controls, the glass-hero pattern) in the agent screens wherever they fit — the single source of the design system. Do not fork a parallel visual kit.
- **`agent_kit.dart` becomes a thin phone-ergonomics layer** over the console system: `AgentButton` (thumb-zone primary), `CountStepper`, `ChoiceRow`, `AgentField`, `StatusBanner`, `BarNote` are **restyled to console tokens** (`context.colors`, `radiusPanel`, Stripe shadow), not a separate look. Delete kit-local colour constants that duplicate console tokens.
- **`AgentScaffold`** restyled to console surfaces and made **theme-aware**: **remove `PinnedDark`**, drive both themes off `context.colors`, and expose a theme toggle in the scaffold (app bar) so a rep can switch in-store (persisted via the app's existing theme-mode controller, shared with the console). Every screen must render correctly in both themes — this is the load-bearing constraint for the whole sub-project.
- **New widgets:** the guided-camera screen/overlay (framing brackets + section hint + thumb shutter + review), a console-tokened inline capture tile, the check-in status/radar.
- **Untouched:** providers, repositories, Drift outbox, geofence, sync engine, backend.
- **Tests:** extend the existing agent tests (24 audit + 4 beatplans) — restyled-screen widget tests, contrast asserts on new pill/card pairs **in both themes**, a theme-toggle test per key screen, reduceMotion static asserts, the guided-capture flow, offline-state rendering. Phone-viewport browser/emulator proof, per the project's build-run-screenshot-and-look practice.

## Scope — decomposition (3 sub-plans, each its own PR)

Sub-5 is ~12 screens; decompose like sub-1–4 (branch each off fresh `main`; PR bases on `main`):

- **5a — System foundation + landing.** Move `agent_kit`/`AgentScaffold` onto console tokens; make the agent app **theme-aware (light + dark)** with the in-scaffold toggle; rebuild **Today** and the **outlet picker** on the console system. Establishes the language, the dual-theme wiring, and the two entry screens.
- **5b — Visit hub, check-in & the 10 sections.** The arrival moment + hub, and the form-heavy sweep unifying **all 10 sections** (including the raw S1/S6–S9) on console-tokened primitives.
- **5c — Capture, outcome, my-work & motion.** The blended inline+guided camera across S3/4 + S5; the score-reveal outcome; the my-work sync queue; the motion/haptics pass; full phone-viewport verification.

## Verification approach

- Widget tests keep behavioural coverage; visual claims verified the project's way: **build, run at a phone viewport, screenshot, and look** — in **both** light and dark, and exercise the in-app theme toggle.
- Contrast re-checked on every new pill/card pair **in both themes**; motion re-tested under `reduceMotion`; offline states rendered and screenshotted (checked-in, too-far, "saved on phone").

## Out of scope

- Backend/data-model changes (none needed).
- The manager console (done in sub-1–4).
- Global search, new capture *requirements* (multi-photo per section, new sections) — this is a redesign of the existing flow, not new data capture.
