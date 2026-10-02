import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state/empty_drawing.dart';
import 'package:tradeiq_app/features/assistant/presentation/ask_first_run.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../agent_harness.dart' show loadAgentFonts;
import 'ask_harness.dart';
import 'assistant_gate_test.dart' show pumpGate, config;

/// ASK TRADEIQ'S OPENING, AND THE THREE DRAWINGS, RENDERED.
///
/// Every other test on this route asserts a capability or counts a pixel of
/// amber. This one produces the images somebody looks at, because the two
/// questions it was built to answer — *does the opening still read as a
/// broken-image placeholder* and *do the three silhouettes look drawn* — are
/// not questions an assertion can answer.
///
/// 390×844, both skins, with Schibsted Grotesk and JetBrains Mono loaded. The test font is
/// wider than Schibsted Grotesk, so a screen rendered in it wraps sooner and measures
/// taller — a picture of the wrong screen.
///
/// | image | what it has to get right |
/// |---|---|
/// | `opening` | the invitation: a headline that leads, no placeholder frame above it |
/// | `offline` | the rows held, the held banner saying why once, the promise still legible |
/// | `loading` | the rows held while the headline and the promise stay at full strength |
/// | `not-enabled` | the envelope, drawn, on the route's own gate |
/// | `drawings` | all three at 64dp on real ground, plus the error colour |
///
/// Tasks' empty state — the other screen that wears one of these — is
/// rendered by `test/features/tasks/tasks_look_test.dart`, which already
/// stands that screen up with no tasks at all.
///
/// ## Why it does not run in CI
///
/// The reason `floor_look_test.dart` and `tasks_look_test.dart` give: CI
/// rasterises anti-aliased Schibsted Grotesk on `ubuntu-latest` and this repository is
/// developed on macOS, so a pixel comparison fails on the day it lands and
/// gets skipped within a week. The images are an artefact to *look at*; the
/// pins are the measurements in `chat_screen_test.dart`,
/// `ask_semantics_test.dart` and `ask_amber_census_test.dart`, which do run
/// everywhere.
///
/// ```sh
/// ASK_LOOK=1 ASK_LOOK_DIR=/somewhere/ flutter test \
///   test/features/assistant/ask_look_test.dart --update-goldens
/// ```
///
/// **`ASK_LOOK_SIZE=360x640`** shoots the same screens on the cheap-Android
/// width. The default stays 390×844, so the committed goldens are byte-for-byte
/// what they were; the size travels into the filename, so the two sets never
/// overwrite one another. The three-silhouette strip keeps its own 220dp
/// height — it is a specimen of the drawings, not a screen, and the phone's
/// height means nothing to it.
/// **`ASK_LOOK_SCALE=1.3`** shoots the same screens at the text scale a
/// cheap Android ships with the accessibility slider nudged once. The default
/// stays 1.0, so the committed goldens are byte-for-byte what they were, and
/// the scale travels into the filename so the two sets never collide. It is
/// the frame that decides whether the ask bar still fits a 640dp fold.
void main() {
  final looking = Platform.environment['ASK_LOOK'] == '1';
  final dir = Platform.environment['ASK_LOOK_DIR'] ?? 'goldens/';
  final scale = _scaleFromEnv();
  final sfx = _scaleTag(scale);

  setUpAll(() async {
    await loadAgentFonts();
    await _loadIcons();
  });

  final phone = _sizeFromEnv() ?? const Size(390, 844);
  final tag = '${phone.width.toInt()}x${phone.height.toInt()}';

  const skins = <(String, bool)>[('night', true), ('day', false)];

  TiqSkin console(bool night) => night
      ? TiqSkin.night(density: TiqDensity.console)
      : TiqSkin.day(density: TiqDensity.console);

  for (final (name, night) in skins) {
    // ── 1. The opening ───────────────────────────────────────────────────
    //
    // The screen a manager meets first. It is an invitation to ask a
    // question, not a report that something is missing, and this image is how
    // that claim is checked.
    testWidgets('Ask — the opening, $name', (tester) async {
      await pumpAsk(tester, skin: console(night), size: phone, textScale: scale);

      await expectLater(
        find.byKey(askBoundaryKey),
        matchesGoldenFile('${dir}ask_$tag-opening-$name$sfx.png'),
      );
      await disposeAsk(tester);
    }, skip: !looking);

    // ── 2. Offline ───────────────────────────────────────────────────────
    //
    // The teaching text stays at full strength because it is still true; the
    // rows go to ink-mute and take no press. The reason is said once, by the
    // route's held banner above the composer — not four times, once per row.
    testWidgets('Ask — the opening offline, $name', (tester) async {
      await pumpAsk(tester, skin: console(night), size: phone, textScale: scale, online: false);

      await expectLater(
        find.byKey(askBoundaryKey),
        matchesGoldenFile('${dir}ask_$tag-offline-$name$sfx.png'),
      );
      await disposeAsk(tester);
    }, skip: !looking);

    // ── 3. Loading ───────────────────────────────────────────────────────
    //
    // The headline and the promise are already true and are shown at once;
    // only the rows are held. Rendered as a component rather than through the
    // route, because no call site in the app passes `loading` today — the gate
    // renders its own skeleton instead. See the flag's own doc.
    testWidgets('Ask — the opening loading, $name', (tester) async {
      await _pumpFirstRun(
        tester,
        skin: console(night),
        size: phone,
        textScale: scale,
        loading: true,
      );

      await expectLater(
        find.byKey(_frameKey),
        matchesGoldenFile('${dir}ask_$tag-loading-$name$sfx.png'),
      );
    }, skip: !looking);

    // ── 4. The gate's own empty state ────────────────────────────────────
    //
    // `AskNotEnabled` is a genuine empty state and keeps its drawing. This is
    // the envelope in its real context, on the route's own chrome.
    testWidgets('Ask — not switched on, $name', (tester) async {
      await pumpGate(
        tester,
        config(assistantEnabled: false),
        skin: console(night),
        size: phone,
        textScale: scale,
      );

      await expectLater(
        find.byKey(askBoundaryKey),
        matchesGoldenFile('${dir}ask_$tag-not-enabled-$name$sfx.png'),
      );
    }, skip: !looking);

    // ── 5. The three drawings, at size ───────────────────────────────────
    //
    // On real `ground`, at the declared 64dp extent, in the empty state's
    // colour and the error state's — `error_state.dart` paints the same
    // drawing in `bad`, and a silhouette that only works in grey is half a
    // drawing.
    testWidgets('Ask — the three drawings, $name', (tester) async {
      await _pumpDrawings(tester, skin: console(night));

      await expectLater(
        find.byKey(_frameKey),
        matchesGoldenFile('${dir}drawings_${phone.width.toInt()}x220-$name$sfx.png'),
      );
    }, skip: !looking);
  }
}

const Key _frameKey = ValueKey<String>('look-frame');

/// One `AskFirstRun`, on real ground, at a phone's width — for the state no
/// route stands up on its own.
Future<void> _pumpFirstRun(
  WidgetTester tester, {
  required TiqSkin skin,
  required Size size,
  double textScale = 1.0,
  bool enabled = true,
  bool loading = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 1.0,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: MaterialApp(
        theme: AppTheme.torchlight(skin),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: RepaintBoundary(
          key: _frameKey,
          child: DefaultTextStyle(
            style: skin.text.body.style(color: skin.palette.ink1),
            child: ColoredBox(
              color: skin.palette.ground,
              child: Padding(
                padding: EdgeInsets.all(skin.space.gutter),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: AskFirstRun(
                    onAsk: (_) {},
                    enabled: enabled,
                    loading: loading,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The three silhouettes side by side, twice: the empty state's colour on the
/// top row and the error state's on the bottom.
Future<void> _pumpDrawings(WidgetTester tester, {required TiqSkin skin}) async {
  final size = Size(_sizeFromEnv()?.width ?? 390, 220);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  Widget row(Color colour) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      for (final drawing in EmptyDrawing.values)
        EmptyStateDrawing(drawing: drawing, color: colour),
    ],
  );

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 1.0,
        disableAnimations: true,
      ),
      child: MaterialApp(
        theme: AppTheme.torchlight(skin),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: RepaintBoundary(
          key: _frameKey,
          child: ColoredBox(
            color: skin.palette.ground,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                row(skin.palette.edgeControl),
                row(skin.palette.bad),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The icon font, out of the Flutter SDK's own cache.
///
/// It is not in the test asset bundle, so without this the header's refresh
/// control and all four nav destinations are hollow boxes. Its absence is
/// silent and harmless — a look test has no business failing over an icon on a
/// machine that keeps its SDK somewhere else.
Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? Directory('$root/bin/cache')
      : File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;
  await (FontLoader(
    'MaterialIcons',
  )..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}

/// `ASK_LOOK_SIZE=360x640` → `Size(360, 640)`; anything else → null.
///
/// The same contract `agent_look_test.dart` carries, for the same reason: the
/// prose face and the type scale both moved on 1 October 2026 and every
/// harness had to be re-shot at the cheap-Android width as well as the
/// reference phone. Silent on a malformed value on purpose — these images are
/// an artefact to look at, and a throw here would read as a broken screen
/// rather than as a typo in a shell variable.
Size? _sizeFromEnv() {
  final raw = Platform.environment['ASK_LOOK_SIZE'];
  if (raw == null) return null;
  final parts = raw.toLowerCase().split('x');
  if (parts.length != 2) return null;
  final w = double.tryParse(parts[0]);
  final h = double.tryParse(parts[1]);
  if (w == null || h == null || w <= 0 || h <= 0) return null;
  return Size(w, h);
}

/// `ASK_LOOK_SCALE=1.3` -> 1.3; absent or malformed -> 1.0.
///
/// Silent on a bad value for the same reason the size switch is: these images
/// are an artefact to look at, and a typo should produce the reference frame
/// rather than a crash in a tool somebody is using to see a screen.
double _scaleFromEnv() {
  final raw = Platform.environment['ASK_LOOK_SCALE'];
  final parsed = raw == null ? null : double.tryParse(raw);
  if (parsed == null || parsed < 1.0 || parsed > 3.0) return 1.0;
  return parsed;
}

/// The scale's mark in a golden's name. Empty at 1.0, so every committed
/// filename is unchanged.
String _scaleTag(double scale) =>
    scale == 1.0 ? '' : '-x${(scale * 10).round()}';
