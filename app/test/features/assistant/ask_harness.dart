import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_repository.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/presentation/chat_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

/// Everything Ask TradeIQ's tests need to stand the route up without a server.
///
/// The fakes replace the **repository**, never the controller above it, so
/// the event handling, the phase decision, the focus resolution and the
/// provenance guard all run for real. A test that overrode
/// `chatControllerProvider` would prove only that a widget can draw a record.

// ── Repositories ──────────────────────────────────────────────────────

/// Plays the same script for every question.
class ScriptedRepository implements AssistantRepository {
  ScriptedRepository(this.script);

  final List<AssistantEvent> script;
  final List<String> sent = <String>[];
  final List<List<ChatHistoryEntry>> histories = <List<ChatHistoryEntry>>[];

  @override
  Stream<AssistantEvent> chat({
    required String message,
    List<ChatHistoryEntry> history = const <ChatHistoryEntry>[],
    String? conversationId,
    CancelToken? cancelToken,
  }) async* {
    sent.add(message);
    histories.add(history);
    for (final event in script) {
      yield event;
    }
  }
}

/// A turn the test drives event by event, so the screen can be read
/// mid-stream. Later turns play [then] and end.
class LiveRepository implements AssistantRepository {
  LiveRepository({this.then = const <AssistantEvent>[DoneEvent()]});

  final List<AssistantEvent> then;
  final List<String> sent = <String>[];
  StreamController<AssistantEvent>? _turn;

  @override
  Stream<AssistantEvent> chat({
    required String message,
    List<ChatHistoryEntry> history = const <ChatHistoryEntry>[],
    String? conversationId,
    CancelToken? cancelToken,
  }) {
    sent.add(message);
    if (_turn != null) return Stream<AssistantEvent>.fromIterable(then);
    _turn = StreamController<AssistantEvent>();
    return _turn!.stream;
  }

  void emit(AssistantEvent event) => _turn!.add(event);

  /// End the stream. Not awaited: after Stop the listener has cancelled, and
  /// a cancelled single-subscription controller's `close()` never completes.
  Future<void> close() async {
    final turn = _turn;
    if (turn != null && !turn.isClosed) unawaited(turn.close());
  }

  /// Drop the connection without a `done` frame.
  void fail(Object error) => _turn!.addError(error);
}

/// A clock the test steps by hand.
class StepClock {
  DateTime now = DateTime.utc(2026, 9, 1, 9);

  void advance(Duration by) => now = now.add(by);

  DateTime call() => now;
}

// ── Fixtures ──────────────────────────────────────────────────────────

const String stockTool = 'getStockLevels';

/// A ranking the server named a focus for, through the `focus` event.
List<AssistantEvent> rankedTurn({
  String id = 'getStockLevels-ranked_bars-1',
  int? focus = 0,
  bool focusInData = false,
  String origin = 'internal',
  String text = 'Three outlets ran out most often.',
}) => <AssistantEvent>[
  const ToolStartEvent(name: stockTool, pillar: 'stock'),
  const ToolEndEvent(name: stockTool, ok: true),
  ArtifactEvent(
    id: id,
    type: 'ranked_bars',
    params: const <String, dynamic>{},
    data: <String, dynamic>{
      'title': 'Out-of-stock lines by outlet',
      'unit': 'count',
      'origin': origin,
      'outsideData': origin != 'internal',
      'items': const <Map<String, dynamic>>[
        <String, dynamic>{'label': 'Spar Soweto', 'value': 6},
        <String, dynamic>{'label': 'Shoprite Klipfontein', 'value': 4},
        <String, dynamic>{'label': 'Pick n Pay Rosebank', 'value': 2},
      ],
      if (focusInData && focus != null) 'focusIndex': focus,
    },
  ),
  if (focus != null && !focusInData) FocusEvent(artifactId: id, index: focus),
  TokenEvent(text),
  const DoneEvent(),
];

/// Tiles only: four numbers together are the reading, and nothing is lit.
List<AssistantEvent> tilesTurn({
  num? value = 1284990.5,
  String unit = 'count',
  String text = 'Sell-in held steady.',
}) => <AssistantEvent>[
  const ToolStartEvent(name: 'getSalesPerformance', pillar: 'sales'),
  const ToolEndEvent(name: 'getSalesPerformance', ok: true),
  ArtifactEvent(
    id: 'getSalesPerformance-stat_tiles-1',
    type: 'stat_tiles',
    params: const <String, dynamic>{},
    data: <String, dynamic>{
      'outsideData': false,
      'tiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'label': 'Sell-in, units',
          'value': value,
          'unit': unit,
          'origin': 'internal',
        },
      ],
    },
  ),
  TokenEvent(text),
  const DoneEvent(),
];

/// A trend chart and no ranking: its primary series is the one focus.
List<AssistantEvent> chartTurn({String text = 'Availability recovered.'}) =>
    <AssistantEvent>[
      const ToolStartEvent(name: 'getMetricTrend', pillar: 'stock'),
      const ToolEndEvent(name: 'getMetricTrend', ok: true),
      const ArtifactEvent(
        id: 'getMetricTrend-0',
        type: 'trend_chart',
        params: <String, dynamic>{'metric': 'availability'},
        data: <String, dynamic>{
          'metric': 'availability',
          'points': <Map<String, dynamic>>[
            <String, dynamic>{'period': '2026-06', 'value': 58},
            <String, dynamic>{'period': '2026-07', 'value': 61},
            <String, dynamic>{'period': '2026-08', 'value': 66},
          ],
        },
      ),
      TokenEvent(text),
      const DoneEvent(),
    ];

// ── The pump ──────────────────────────────────────────────────────────

const Key askBoundaryKey = ValueKey<String>('amber-golden-boundary');

/// Stand Ask TradeIQ up on a 360×640 phone, Night × Console by default.
///
/// [disableAnimations] defaults to true: the caret, the busy dots and the
/// running dot's pulse are the route's only repeating animations, and a
/// repeating animation makes `pumpAndSettle` hang. The census of the
/// *thinking* phase turns it off, because under reduce-motion the pulse is a
/// word and not a light — and then pumps a fixed number of frames.
Future<void> pumpAsk(
  WidgetTester tester, {
  AssistantRepository? repository,
  TiqSkin? skin,
  Size size = const Size(360, 640),
  double textScale = 1.0,
  double keyboard = 0,
  Locale locale = const Locale('en'),
  bool online = true,
  bool sessionEnded = false,
  StepClock? clock,
  bool disableAnimations = true,
  bool settle = true,
  List<Override> extraOverrides = const <Override>[],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final resolved = skin ?? TiqSkin.night(density: TiqDensity.console);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        assistantRepositoryProvider.overrideWithValue(
          repository ?? ScriptedRepository(const <AssistantEvent>[]),
        ),
        askOnlineProvider.overrideWithValue(online),
        // The real provider reads the session controller, which reaches for
        // secure storage. The state is what is under test, not the plumbing.
        askSessionEndedProvider.overrideWithValue(sessionEnded),
        if (clock != null) assistantClockProvider.overrideWithValue(clock.call),
        ...extraOverrides,
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 1.0,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: MaterialApp.router(
          theme: AppTheme.torchlight(resolved),
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          localeListResolutionCallback: resolveAppLocale,
          // Around the whole frame: the nav pill and the composer are
          // siblings of the scroll view, and the nav tab is Night's object 1.
          builder: (context, child) =>
              RepaintBoundary(key: askBoundaryKey, child: child!),
          routerConfig: GoRouter(
            initialLocation: '/assistant',
            routes: <RouteBase>[
              GoRoute(
                path: '/assistant',
                builder: (context, state) => const AssistantChatScreen(),
              ),
              GoRoute(
                path: '/login',
                builder: (context, state) => const Text('login'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// The composer's trough.
Finder get composerField => find.byType(EditableText);

/// Type [question] and press the keyboard's Send.
Future<void> ask(
  WidgetTester tester,
  String question, {
  bool settle = true,
}) async {
  await tester.enterText(composerField, question);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Let an emitted event reach the screen.
///
/// Two frames: the stream delivers on a microtask, which can land after the
/// frame the first pump builds, so the rebuild it schedules is the second.
Future<void> pumpEvent(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// A handful of fixed frames, for a route with something repeating on it.
Future<void> pumpFrames(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmount inside the test body, so a timer the route armed — the stall
/// threshold, the send debounce — is cancelled before the binding checks.
Future<void> disposeAsk(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  // A sheet left open when the tree is torn down never pops, and the sheet
  // count is static: the next test's first sheet would be "a second sheet".
  TorchSheets.resetForTest();
}

/// Every string a reader can currently see in rich text.
String screenText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((w) => w.text.toPlainText())
    .join('\n');

/// The three skins, Console density where a density applies.
List<TiqSkin> get askSkins => <TiqSkin>[
  TiqSkin.night(density: TiqDensity.console),
  TiqSkin.day(density: TiqDensity.console),
  TiqSkin.veld(),
];

/// One answer block on its own, in a Torchlight skin, at a phone panel's
/// inner width — for the cards, without the route around them.
///
/// [reduce] defaults to true, so a bar's grow-in lands on the first frame and
/// nothing repeats; pass false to watch the motion.
Widget askBlock(
  Widget child, {
  TiqSkin? skin,
  bool reduce = true,
  Locale locale = const Locale('en'),
  double width = 320,
  double textScale = 1.0,
}) {
  final resolved = skin ?? TiqSkin.night(density: TiqDensity.console);
  return MaterialApp(
    theme: AppTheme.torchlight(resolved),
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduce,
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle(
          style: resolved.text.body.style(color: resolved.palette.ink1),
          child: ColoredBox(
            color: resolved.palette.surface,
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
