import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

import '../agent_harness.dart' show loadAgentFonts;
import 'ask_brief_test.dart' show briefTurn;
import 'ask_harness.dart';

/// THE BRIEF, RENDERED — so it can be looked at before it is shipped.
///
/// Skipped unless `ASK_LOOK=1`: it writes PNGs, which is not a test. The
/// shipped faces are loaded first, because a layout judged in the default
/// test font wraps sooner and measures taller than the one a manager sees.
///
/// ```
/// ASK_LOOK=1 ASK_LOOK_DIR=/somewhere/ flutter test \
///   test/features/assistant/ask_brief_look_test.dart
/// ```
void main() {
  final looking = Platform.environment['ASK_LOOK'] == '1';
  final dir = Platform.environment['ASK_LOOK_DIR'] ?? 'build/ask-look/';

  setUpAll(() async {
    await loadAgentFonts();
    await _loadIcons();
  });

  /// Rasterise and write. Inside `runAsync`, because `toImage` and the PNG
  /// encoder finish on a thread the test's fake clock does not drive.
  Future<void> write(WidgetTester tester, String name) async {
    final render = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(askBoundaryKey),
    );
    final bytes = await tester.runAsync(() async {
      final shot = await render.toImage();
      return shot.toByteData(format: ui.ImageByteFormat.png);
    });
    final file = File('$dir$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('  wrote ${file.path}');
  }

  for (final (tag, size, turn) in <(String, Size, List<Object> Function())>[
    ('brief-1440', const Size(1440, 900), briefTurn),
    ('brief-1190', const Size(1190, 760), briefTurn),
    ('ranked-1440', const Size(1440, 900), rankedTurn),
    ('tiles-1440', const Size(1440, 900), tilesTurn),
    ('brief-phone', const Size(390, 844), briefTurn),
  ]) {
    testWidgets(tag, (tester) async {
      await pumpAsk(
        tester,
        repository: ScriptedRepository(turn().cast()),
        skin: TiqSkin.night(density: TiqDensity.console),
        size: size,
        clock: StepClock(),
      );
      await ask(tester, 'How many outlets do we have?');
      await write(tester, tag);
      await disposeAsk(tester);
    }, skip: !looking);
  }
}

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
