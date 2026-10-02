/// THE AMBER CENSUS, ONE TABLE, EVERY SCREEN THAT LIGHTS AMBER, BOTH SKINS.
///
/// Roughly seventy-five tests in this suite call `amberCensus`, and between
/// them they cover more screens than this file does. What none of them does is
/// put the numbers **in one place where a person can read them off**, and that
/// turned out to matter: the question "did the amber ramp change how many
/// objects each screen lights" has to be answerable in one run, by one table,
/// or it gets answered by a screenshot.
///
/// So this is the five look harnesses' screens — the five the owner is shown —
/// counted from pixels, in Night and Day, with the counts asserted *and*
/// printed. The print is the artefact; the assertion is what stops the artefact
/// becoming decoration. A test that only printed could not fail, and this
/// repository is right to refuse those.
///
/// ## The table, as of 1 October 2026
///
/// | screen | Night | Day |
/// |---|---|---|
/// | The Floor, at rest | 2 | 1 |
/// | Ask TradeIQ, composer at rest | 2 | 1 |
/// | Ask TradeIQ, Send armed | 2 | 1 |
/// | Tasks | 1 | 0 |
/// | Today (agent), a walking order | 2 | 1 |
/// | Sign-in, armed | 2 | 1 |
///
/// Read the Night column against `TorchScope.budgetFor`, which is **two** on a
/// dark ground and **one** on paper. Every row is at its budget or under it,
/// and which objects they are is worth knowing:
///
/// * **The Floor** lights the plate's strip light and the composer's Send disc.
///   The strip light needs a photograph to be a light *on* — with no plate
///   image it declines its own grant and the count is 1, not 2, which is why
///   this fixture supplies a real one.
/// * **Ask** and **Tasks** light the nav pill's active tab, and Ask lights its
///   Send disc beside it. Send is armed from the first frame, so "at rest" and
///   "armed" are the same count; the row is kept because the *reason* they
///   match is a decision (an empty trough redirects the press into the trough
///   rather than disabling the key) and not an accident.
/// * **Today** lights the filled `Check in here` commit and the nav tab.
/// * **Sign-in** lights the commit and, on Night only, the amber underline
///   under "Forgot password?" — rung 5, granted because a formless route never
///   spends Night's slot 1 on chrome. Day's budget is one, the commit takes it,
///   and the underline falls back to `edgeControl`.
/// * **Tasks on Day is zero**, and that is correct rather than broken: there is
///   no commit action on a worklist, and on a light ground nothing else may be
///   amber at all.
///
/// ## What it caught, and did not
///
/// It was built to answer whether the 1 October 2026 amber work moved any of
/// these. It did not: the counts and the region bounds are identical before the
/// ramp, after the ramp, and after the fill gradients. Three screens moved by a
/// single lit *pixel*, which is anti-aliasing at a gradient's rim and is
/// reported rather than budgeted — see `AmberCensus.litFraction`.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/tasks/presentation/tasks_screen.dart';

import '../core/design/amber_golden.dart';
import 'agent_harness.dart';
import 'assistant/ask_harness.dart';
import 'auth/entry_harness.dart';
import 'dashboard/floor_harness.dart' hide FakeTasksRepository;
import 'worklist_harness.dart' hide outlet;

const Size phone = Size(390, 844);

/// Print the row, then assert it — in that order, so a failing run still
/// leaves the number it measured in the log beside the one it wanted.
void row(
  String route,
  String skin,
  TiqSkin budgetSkin,
  AmberCensus c,
  int expected,
) {
  // ignore: avoid_print
  print(
    'CENSUS | ${route.padRight(26)} | ${skin.padRight(5)} | '
    'objects=${c.objectCount} | '
    'lit=${c.litPixels} (${(c.litFraction * 100).toStringAsFixed(2)}%) | '
    '${c.regions.join(' ; ')}',
  );
  expectWithinAmberBudget(c, budgetSkin, route: route, phase: 'look');
  // …and the count the ladder predicted, not merely under it. "Under budget"
  // passes for a screen that lost its light entirely, which is the failure
  // this file exists to notice.
  expect(
    c.objectCount,
    expected,
    reason: '$route [$skin] painted ${c.objectCount}, expected $expected\n'
        '${c.describe()}',
  );
}

const _kasi = Outlet(
  id: 'o1',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.2400,
  lng: 27.8580,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-0221',
  lat: -26.2520,
  lng: 27.8580,
);

final _todaysRoute = TodayRoute(
  planName: 'Naledi · Soweto East',
  hasLocation: true,
  stops: <RouteStop>[
    const RouteStop(sequence: 1, outlet: _kasi, visited: true, distanceMeters: 1200),
    const RouteStop(sequence: 2, outlet: _sunrise, visited: false, distanceMeters: 420),
  ],
);

void main() {
  setUpAll(loadAgentFonts);

  for (final (name, mode) in <(String, SkinMode)>[
    ('night', SkinMode.night),
    ('day', SkinMode.day),
  ]) {
    final skin = mode == SkinMode.night ? TiqSkin.night() : TiqSkin.day();

    testWidgets('FLOOR_LOOK $name', (tester) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        size: phone,
        skin: skin,
        plateImage: await SyncImage.fromFile(
          tester,
          '../backend/assets/places/ALL.jpg',
        ),
        current: kpis(osa: 61, execution: 73, priceCompliance: 74),
        previous: kpis(osa: 64, execution: 92),
        outlets: <Outlet>[outlet('o1', 'SaveMor Glenwood')],
        alerts: <AlertItem>[
          alert(
            id: 'a1',
            outletId: 'o1',
            message: 'Kalahari Cola 2L out of stock (6 days)',
            createdAt: DateTime.utc(2026, 9, 16, 9, 6),
          ),
        ],
      );
      row(
        'FLOOR_LOOK at rest',
        name,
        skin,
        await amberCensus(tester),
        // Night: the plate's strip light and the composer's Send disc. Day:
        // the plate is unlit on a light ground, so Send alone.
        mode == SkinMode.night ? 2 : 1,
      );
    });

    testWidgets('ASK_LOOK $name', (tester) async {
      await pumpAsk(
        tester,
        skin: skin,
        size: phone,
        repository: ScriptedRepository(const <AssistantEvent>[]),
      );
      row(
        'ASK_LOOK composer at rest',
        name,
        skin,
        await amberCensus(tester),
        // Night: the nav pill's active tab, and Send. Day: Send alone — the
        // active tab is an Abyssal ink block on paper.
        mode == SkinMode.night ? 2 : 1,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('ask-composer-field')),
        'Which outlets are out of stock?',
      );
      await tester.pumpAndSettle();
      row(
        'ASK_LOOK send armed',
        name,
        skin,
        await amberCensus(tester),
        // The same count, because Send is armed from the first frame: an empty
        // trough redirects the press into the trough rather than disabling the
        // key. Typing changes what the key announces, not whether it is lit.
        mode == SkinMode.night ? 2 : 1,
      );
    });

    testWidgets('TASKS_LOOK $name', (tester) async {
      await pumpWorklist(
        tester,
        TasksScreen(clock: () => DateTime.utc(2026, 9, 18, 9)),
        skin: skin,
        size: phone,
        banner: false,
        overrides: <Override>[
          tasksAdminRepositoryProvider.overrideWithValue(
            FakeTasksRepository(
              clock: () => DateTime.utc(2026, 9, 18, 9),
              tasks: <TaskItem>[
                TaskItem(
                  id: 't1',
                  findingType: 'out_of_stock',
                  requiredFix: 'Fix the end cap at SaveMor Glenwood',
                  priority: 'high',
                  status: 'open',
                  closureVerified: false,
                  outletId: 'o1',
                  slaDueAt: DateTime.utc(2026, 9, 19, 9),
                  createdAt: DateTime.utc(2026, 9, 17, 8),
                ),
              ],
            ),
          ),
        ],
      );
      row(
        'TASKS_LOOK',
        name,
        skin,
        await amberCensus(tester),
        // Night: the nav tab. Day: ZERO, and that is correct — a worklist has
        // no commit action, and on a light ground nothing else may be amber.
        mode == SkinMode.night ? 1 : 0,
      );
    });

    testWidgets('AGENT_LOOK $name', (tester) async {
      await pumpAgentScreen(
        tester,
        const TodayScreen(),
        size: phone,
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: mode),
          todayRouteProvider.overrideWith((ref) async => _todaysRoute),
        ],
      );
      row(
        'AGENT_LOOK today route',
        name,
        skin,
        await amberCensus(tester),
        // Night: the filled `Check in here` commit and the nav tab. Day: the
        // commit alone.
        mode == SkinMode.night ? 2 : 1,
      );
    });
  }

  for (final mode in entrySkinModes) {
    testWidgets('ENTRY_LOOK ${mode.name}', (tester) async {
      await pumpEntryScreen(
        tester,
        const LoginScreen(),
        path: '/login',
        overrides: entryBaseOverrides(db: entryTestDb(), skin: mode),
      );
      row(
        'ENTRY_LOOK sign-in armed',
        mode.name,
        entrySkinFor(mode),
        await amberCensus(tester),
        // Night: the commit, and the amber underline under "Forgot password?"
        // at rung 5 — a formless route never spends slot 1 on chrome, so the
        // budget of two is genuinely available. Day's budget is one, the
        // commit takes it, and the underline falls back to edge-control.
        mode == SkinMode.night ? 2 : 1,
      );
    });
  }
}
