import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/console_frame.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_repository.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/presentation/chat_screen.dart'
    show askOnlineProvider, askSessionEndedProvider;

import '../../../features/agent_harness.dart' show loadAgentFonts;
import '../../../features/assistant/ask_harness.dart' show LiveRepository;
import '../../../features/worklist_harness.dart';

/// THE ASK BAR, RENDERED — the picture the owner judges.
///
/// > *"the bottom doesn't look proportioned"* — the owner, 3 October 2026.
///
/// Every other test on this bar asserts a number. The question that started
/// this change is not a question an assertion answers: **do the three objects
/// read as one row, and is the left edge straight.** So this writes the images
/// somebody looks at — including a 2× crop of the bar alone, which is the frame
/// the complaint was made about.
///
/// | image | what it has to get right |
/// |---|---|
/// | `rest` | one height, one corner language, a straight left edge |
/// | `typing` | the pill holds 48 for a one-line question |
/// | `wrapped` | and grows for one that does not fit |
/// | `sending` | the Stop key is the same disc Send was |
/// | `stop-pressed` | and its press is the rim thickening, not a shape change |
/// | `offline` | a disabled Send, no amber, the same geometry |
/// | `disabled` | a dead session, likewise |
/// | `crop` | the bar alone at 2×, which is the before/after the owner reads |
///
/// ## It writes its own files rather than going through `matchesGoldenFile`
///
/// Two reasons, both the reason `floor_look_test.dart` and `ask_look_test.dart`
/// are skipped in CI: these are artefacts to **look at**, and a pixel
/// comparison across macOS and `ubuntu-latest` fails on the day it lands. The
/// second is the crop. A golden of the whole screen cannot be cropped to the
/// bar, and the bar is the subject; `toImage` into a `PictureRecorder` gives an
/// exact 2× crop of an exact dp rectangle, with no `image` package and no
/// committed bytes.
///
/// ```sh
/// BAR_LOOK=1 BAR_LOOK_DIR=/somewhere/ flutter test \
///   test/core/widgets/torchlight/one_bar_look_test.dart
/// ```
void main() {
  final looking = Platform.environment['BAR_LOOK'] == '1';
  final dir = Platform.environment['BAR_LOOK_DIR'] ?? 'build/bar-look/';

  // ── ONEST, BECAUSE THE PICTURE IS THE POINT ────────────────────────────
  //
  // The default test font is wider than the one that ships, so a screen
  // rendered in it wraps sooner and measures taller. `one_bar_test.dart` says
  // so in as many words about its own numbers; it is twice as true of an image
  // somebody is going to judge a shape from.
  setUpAll(() async {
    await loadAgentFonts();
    // AND THE ICON FONT. Without it the grid glyph and Send's arrow render as
    // tofu boxes, and the two things this file exists to show are a glyph in a
    // disc and a disc in a row.
    await _loadIcons();
  });

  const boundary = ValueKey<String>('amber-golden-boundary');

  /// Rasterise, optionally crop, encode, write.
  ///
  /// **Inside `runAsync`**, which is not optional. PNG encoding and
  /// `Picture.toImage` both finish on a thread the test's fake clock does not
  /// drive, so an `await` on either from inside the test zone is a hang and
  /// not a slow test — this file hung on its second frame before the wrapper
  /// went on. `matchesGoldenFile` does the same thing for the same reason.
  Future<void> write(
    WidgetTester tester,
    String name, {
    double pixelRatio = 1.0,
    Rect? crop,
  }) async {
    final render = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundary),
    );
    final bytes = await tester.runAsync(() async {
      final shot = await render.toImage(pixelRatio: pixelRatio);
      ui.Image out = shot;
      if (crop != null) {
        final src = Rect.fromLTRB(
          crop.left * pixelRatio,
          crop.top * pixelRatio,
          crop.right * pixelRatio,
          crop.bottom * pixelRatio,
        );
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImageRect(
          shot,
          src,
          Rect.fromLTWH(0, 0, src.width, src.height),
          Paint(),
        );
        out = await recorder.endRecording().toImage(
          src.width.round(),
          src.height.round(),
        );
      }
      return out.toByteData(format: ui.ImageByteFormat.png);
    });
    final file = File('$dir$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('  wrote ${file.path}');
  }

  Future<void> frame(
    WidgetTester tester, {
    required TiqSkin skin,
    required Size size,
    double textScale = 1.0,
    List<Override> overrides = const <Override>[],
  }) => pumpWorklist(
    tester,
    ConsoleFrame(
      phase: 'loaded',
      askHint: 'Ask about your tasks…',
      header: const TorchAppHeader(title: 'Tasks'),
      children: const <Widget>[
        Text('Fix the end cap at SaveMor Glenwood'),
        SizedBox(height: 12),
        Text('Kalahari Cola 2L out of stock, six days'),
      ],
    ),
    skin: skin,
    size: size,
    textScale: textScale,
    path: '/tasks',
    // The red barber-pole across the corner is noise in a picture somebody is
    // looking at to decide whether a shape is finished.
    banner: false,
    overrides: overrides,
  );

  const skins = <(String, bool)>[('night', true), ('day', false)];
  TiqSkin console(bool night) => night
      ? TiqSkin.night(density: TiqDensity.console)
      : TiqSkin.day(density: TiqDensity.console);

  final field = find.byKey(const ValueKey<String>('ask-composer-field'));

  // ── ONE IMAGE PER TEST, WHICH IS NOT A STYLE PREFERENCE ────────────────
  //
  // Two `write`s in one test produced a stale frame: the second image carried
  // the first one's text and had lost Send's amber block, on a screen that
  // `amberCensus` counts as lit when it is pumped alone. The boundary's layer
  // is not re-recorded after `runAsync` has advanced real time, so what came
  // out was a photograph of the previous frame. An artefact harness that
  // quietly photographs the wrong screen is worse than no harness, so every
  // test below pumps once, writes once, and ends.
  for (final (name, night) in skins) {
    for (final (tag, size) in const <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      // ── AT REST, 1.0× AND 1.3× ─────────────────────────────────────────
      for (final scale in const <double>[1.0, 1.3]) {
        final sfx = scale == 1.0 ? '' : '@1.3x';
        testWidgets('bar — rest, $name, $tag$sfx', (tester) async {
          await frame(
            tester,
            skin: console(night),
            size: size,
            textScale: scale,
          );
          await write(tester, 'bar_$tag-rest-$name$sfx');
        }, skip: !looking);
      }

      // ── TYPING: ONE LINE, AND ONE THAT WRAPS ───────────────────────────
      for (final (state, question) in const <(String, String)>[
        ('typing', 'why is availability down?'),
        (
          'wrapped',
          'why is availability down in Gauteng North this week and which '
              'outlets are out of Kalahari Cola',
        ),
      ]) {
        testWidgets('bar — $state, $name, $tag', (tester) async {
          await frame(tester, skin: console(night), size: size);
          await tester.enterText(field, question);
          await tester.pump();
          await write(tester, 'bar_$tag-$state-$name');
        }, skip: !looking);
      }

      // ── SENDING, AND STOP UNDER A FINGER ───────────────────────────────
      //
      // In this bar they are ONE object. `ConsoleAskBar` passes
      // `toolRunning: false`, so a turn in flight resolves to
      // `AskPhase.writing` and the key drawn is Stop in both; there is no
      // separate "sending" disc to photograph. The second frame is therefore
      // Stop *pressed*, which is the state that is genuinely different.
      for (final pressed in const <bool>[false, true]) {
        final state = pressed ? 'stop-pressed' : 'sending';
        testWidgets('bar — $state, $name, $tag', (tester) async {
          final live = LiveRepository();
          await frame(
            tester,
            skin: console(night),
            size: size,
            overrides: <Override>[
              assistantRepositoryProvider.overrideWithValue(live),
            ],
          );
          ProviderScope.containerOf(tester.element(find.byType(ConsoleAskBar)))
              .read(chatControllerProvider.notifier)
              .send('why is availability down in Gauteng North?');
          await tester.pump();
          expect(find.bySemanticsLabel('Stop the answer'), findsOneWidget);

          TestGesture? finger;
          if (pressed) {
            finger = await tester.startGesture(
              tester.getCenter(find.bySemanticsLabel('Stop the answer')),
            );
            await tester.pump(const Duration(milliseconds: 200));
          }
          await write(tester, 'bar_$tag-$state-$name');
          await finger?.up();
          await tester.pump();
          await live.close();
          await tester.pump();
        }, skip: !looking);
      }

      // ── OFFLINE, AND A SESSION THAT HAS ENDED ──────────────────────────
      testWidgets('bar — offline, $name, $tag', (tester) async {
        await frame(
          tester,
          skin: console(night),
          size: size,
          overrides: <Override>[askOnlineProvider.overrideWithValue(false)],
        );
        await write(tester, 'bar_$tag-offline-$name');
      }, skip: !looking);

      testWidgets('bar — disabled, $name, $tag', (tester) async {
        await frame(
          tester,
          skin: console(night),
          size: size,
          overrides: <Override>[
            askSessionEndedProvider.overrideWithValue(true),
          ],
        );
        await write(tester, 'bar_$tag-disabled-$name');
      }, skip: !looking);
    }

    // ── THE CROP: THE BAR ALONE, AT 2× ───────────────────────────────────
    //
    // 390×844 at 1.0× logical, rasterised at 2.0, cropped to the bar's own
    // rect plus 16dp of ground above and below. This is the frame the owner's
    // complaint was about and the one a before/after is read off.
    for (final (state, question) in const <(String, String?)>[
      ('rest', null),
      ('typing', 'why is availability down?'),
    ]) {
      testWidgets('bar — the 2x crop, $state, $name', (tester) async {
        await frame(tester, skin: console(night), size: const Size(390, 844));
        if (question != null) {
          await tester.enterText(field, question);
          await tester.pump();
        }
        final bar = tester.getRect(find.byType(ConsoleAskBar));
        // ignore: avoid_print
        print(
          '  CROP $name $state: bar ${bar.width.toStringAsFixed(1)}'
          'x${bar.height.toStringAsFixed(1)}dp at '
          '${bar.left.toStringAsFixed(1)},${bar.top.toStringAsFixed(1)}',
        );
        await write(
          tester,
          'bar_crop-$state-$name@2x',
          pixelRatio: 2.0,
          crop: Rect.fromLTRB(0, bar.top - 16, 390, bar.bottom + 16),
        );
      }, skip: !looking);
    }
  }
}

/// The Material icon font, out of the Flutter cache. `ask_look_test.dart`'s,
/// verbatim — silent when it is not there, because a missing font is a
/// developer-machine problem and not a failing screen.
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
