# Premium UI: Dual Theme + Motion Design

**Ask:** make the manager console feel premium — add a light theme (keeping dark, with a
toggle), smooth the page-to-page and hamburger-drawer motion, and polish surfaces/interactions.

## Decisions made during brainstorming

- **Both themes, with a toggle.** Light does not replace dark. Default remains dark on first
  run — nobody's console changes until they touch the toggle.
- **Light direction: "Paper & Ink"** (chosen over Warm Ivory and Cool Slate mockups):
  `#F7F8FA` page ground, `#FFFFFF` panels, `#E3E5EA` hairlines, and — critically — the dark
  theme's ink `#14161C` carried forward as the light theme's primary text color, so the two
  modes read as one product. Squared geometry (3px controls / 4px panels) is unchanged in both.
- **Page transitions: Material shared-axis (horizontal)** — chosen over plain fade and full
  slide. It is Material 3's documented pattern for switching between same-hierarchy top-level
  destinations, which is exactly the manager rail's Dashboard↔Tasks↔Alerts case. Implemented
  with Google's `animations` package (`SharedAxisTransition`), not hand-rolled.
- **Drawer:** keep Material's slide physics; add a deeper scrim (no `BackdropFilter` blur —
  real perf tax on Flutter web, where managers live) and a ~20ms-per-row staggered fade-up on
  nav items as the drawer opens.
- **Agent side stays pinned dark** in this pass. The field-agent flow (AgentScaffold screens,
  login/landing) wraps itself in the dark theme, so ~20 agent screens need no light migration
  now. Agent light mode is a separate later ticket.

## 1. Theme architecture

The blocker today: every widget reads static consts (`AppColors.ink1` …), which cannot respond
to a runtime toggle. The fix:

- **`TiqColors` `ThemeExtension`** (`app/lib/core/theme/tiq_colors.dart`) carrying every
  semantic slot the app uses: `plane`, `surface1..3`, `line`, `lineStrong`, `ink1..3`,
  `brand`, `brandHover`, `series1..3`, `good`, `warn`, `crit`, `grid`, `axis`, plus two new
  slots light mode needs: `shadow` (panel drop shadow color) and `scrim` (drawer overlay).
  Two const instances: `TiqColors.dark` (today's exact values, unchanged) and
  `TiqColors.light` (Paper & Ink).
- **`AppTheme.light()` and `AppTheme.dark()`** both built from one shared
  `ThemeData _base(TiqColors c)` so component themes (inputs, buttons, cards, appbar, chips…)
  cannot drift between modes. The extension is registered on both.
- **`context.colors`** — a one-line `BuildContext` extension returning
  `Theme.of(this).extension<TiqColors>() ?? TiqColors.dark` (the fallback keeps
  the 22 pre-existing bare-`MaterialApp` test pumps green; production themes
  always register the extension). Feature code migrates mechanically:
  `AppColors.x` → `context.colors.x`.
- **Migration scope:** core widgets shared by the manager console (`worklist.dart`,
  `console.dart`, `manager_scaffold.dart`, `charts.dart`) and
  all manager/shared feature screens (~24 files, ~200 refs). Agent-only files
  (`agent_kit.dart`, `agent_motion.dart`, audit flow screens, `today_screen.dart`,
  `photo_capture_field.dart`, `primary_gradient_button.dart`, login/landing) keep the statics —
  they are pinned dark, where static values and `TiqColors.dark` are identical by definition.
- **`AppColors` remains** as the dark constant table (it seeds `TiqColors.dark`) and for
  agent-pinned files. New manager code uses `context.colors`.
- **`design/tokens.css`** (authoritative design reference) gains a `[data-theme="light"]`
  block mirroring `TiqColors.light`, alongside the existing dark values.

## 2. Light chart palette

The dark series triple (`#3987E5`, `#199E70`, `#C98500`) and status colors were validated
against panel `#14161C`; they will not all hold 3:1 on white. `TiqColors.light` carries its own
validated triple — darkened variants of the same three hues: `#2069C9` / `#177A57` / `#9A6700`
— and darkened status steps: `good #0B7A0B`, `warn #935F00`, `crit #B32E2E`. All six are
asserted ≥3:1 against `#FFFFFF` by a unit test (see Testing); if any value fails there it is
darkened until the test passes, and the spec value updated to match. `charts.dart` reads the scheme via `context.colors`, so charts follow the
toggle with no logic changes. Slot discipline is unchanged: status colors are never series
colors; meaning never rides on color alone.

## 3. Toggle, persistence, and scope guard

- **`themeModeProvider`** (Riverpod `Notifier<ThemeMode>`, `app/lib/core/theme/theme_mode_controller.dart`),
  persisted under key `tiq.themeMode` in the already-present `flutter_secure_storage` (no new
  dependency; not a secret, but not worth a second storage stack). Values: `light`/`dark` only.
  Missing/unreadable → `dark`. `ThemeMode.system` is deliberately out of scope (managers on
  desktop web; two explicit modes are clearer than three).
- **`MaterialApp.router`** gets `theme: AppTheme.light()`, `darkTheme: AppTheme.dark()`,
  `themeMode: ref.watch(themeModeProvider)`.
- **Toggle control:** a sun/moon `IconButton` in the ManagerScaffold top bar, keyed
  `theme-toggle`, tooltip "Switch to light/dark theme".
- **Agent pinning:** a tiny `PinnedDark` wrapper widget
  (`Theme(data: AppTheme.dark(), child: …)`) applied inside `AgentScaffold`, and around the
  login/landing screens' scaffolds. Widget test asserts an agent screen's scaffold stays dark
  while `themeModeProvider` is light.

## 4. Motion

- **Shared-axis page transitions** for manager routes: one helper in
  `app/lib/core/router/manager_page.dart` —
  `CustomTransitionPage` whose `transitionsBuilder` returns
  `SharedAxisTransition(transitionType: horizontal, fillColor: context.colors.plane)`,
  duration 250ms. Every manager-shell `GoRoute` switches from `builder:` to
  `pageBuilder: managerPage(...)`. Agent audit routes keep their existing `agent_motion.dart`
  treatment untouched.
- **Reduced motion:** when `MediaQuery.disableAnimationsOf(context)` is true, the helper falls
  back to a plain 100ms fade (and the drawer stagger below is skipped).
- **Drawer polish** in `manager_scaffold.dart`: scrim from `context.colors.scrim`
  (deeper than Flutter's default black54 wash in light mode; tuned per scheme), and nav rows
  animate in with a staggered fade-up — ~20ms delay per row, 150ms per row, driven by one
  `AnimationController` started on drawer open. No change to the drawer's slide itself.

## 5. Premium polish pass (rides on the tokens)

- **Elevation:** light mode cannot lean on borders alone. Panels (`PanelCard`, KPI tiles,
  dialogs) get a two-layer soft shadow from `context.colors.shadow` — barely-there at rest
  (`0 1px 2px @ 6%`), lifted on hover (`0 4px 12px @ 10%`). Dark mode keeps `shadow`
  transparent — its borders already do this job; zero visual change to dark.
- **Interaction states:** `WorklistRow` and rail/drawer nav items get explicit hover
  (`surface2`) and pressed (`surface3`) washes in both modes; state changes animate at 150ms.
- **Focus:** visible focus ring standardizes on `brand` at 1.5px for keyboard navigation.
- **No layout changes.** Same screens, same information architecture, same copy — only
  surfaces, motion, and state feedback.

## Testing

- Widget tests: toggling `themeModeProvider` flips a manager screen's scaffold color between
  `TiqColors.dark.plane` and `TiqColors.light.plane`; agent screen stays dark under a light
  `themeMode`; toggle button flips and persists the mode (fake storage); reduced-motion fall
  back builds `FadeTransition` not `SharedAxisTransition`.
- Existing suite (366 app tests) must stay green — the dark theme's values are unchanged, so
  no existing color assertion should move.
- Light chart triple + status steps get a small unit test asserting ≥3:1 contrast against
  white (relative-luminance math, ~15 lines), so palette regressions fail loudly.

## Out of scope

- Agent-side light mode (pinned dark; later ticket).
- `ThemeMode.system`.
- Backdrop blur on the drawer scrim (web perf).
- Any layout, navigation-structure, or copy changes.
- The marketing/landing HTML in `design/*.html` (tokens.css is updated; page mockups are not).

## Execution shape

One spec (this document), two sequential implementation plans:

- **Plan A — theme system:** `TiqColors`, dual `AppTheme`, `context.colors`, provider +
  toggle + persistence, agent pinning, mechanical migration of core + manager files, light
  chart palette + contrast test, `tokens.css` light block.
- **Plan B — motion & polish:** `animations` dependency, shared-axis `managerPage` helper on
  all manager routes, reduced-motion fallback, drawer scrim + stagger, shadows/hover/pressed/
  focus states.

Plan B depends on Plan A's tokens; they are not parallelizable.
