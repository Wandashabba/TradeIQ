import 'dart:io';

/// One hardcoded style decision found in the source tree.
class StyleViolation {
  StyleViolation({
    required this.file,
    required this.line,
    required this.kind,
    required this.text,
  });

  final String file;
  final int line;
  final String kind;
  final String text;

  @override
  String toString() => '$file:$line  $kind  ${text.trim()}';
}

/// The three things that are not allowed to be decided inside a feature.
///
/// - `Color(0x…)` — a raw colour. There are 25 named colour tokens; a hex in a
///   screen means one of them is wrong or missing.
/// - `Colors.…` — Material's palette. It has no relationship to this system;
///   `Colors.transparent` is the one allowed member, because it is the absence
///   of a colour rather than a choice of one.
/// - `TextStyle(` — a bare text style. Sixteen roles are declared; a screen
///   that builds its own is a seventeenth nobody reviewed. `.copyWith(` on a
///   token is fine — that is how you set a colour on a role.
class TorchlightScanner {
  TorchlightScanner._();

  static final RegExp _rawColor = RegExp(r'Color\(0x');
  static final RegExp _materialColors = RegExp(r'(?<![A-Za-z0-9_$])Colors\.');
  static final RegExp _bareTextStyle = RegExp(
    r'(?<![A-Za-z0-9_$.])TextStyle\(',
  );

  /// `Colors.transparent` is the absence of a colour, not a choice of one.
  static final RegExp _allowedColorsMember = RegExp(
    r'(?<![A-Za-z0-9_$])Colors\.transparent(?![A-Za-z0-9_$])',
  );

  /// A line the author has explicitly excused, with the reason on the same
  /// line. The marker is deliberately verbose: it has to be unpleasant enough
  /// to type that nobody sprays it across a file.
  static const String escapeHatch = 'torchlight-ignore:';

  static List<StyleViolation> scan(Directory root) {
    final out = <StyleViolation>[];
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final rel = _relative(file.path, root.path);
      var inBlockComment = false;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];

        // Strip block comments spanning lines, then line comments, so a hex in
        // a doc comment (there are several, explaining why a token exists) is
        // not a violation.
        if (inBlockComment) {
          final end = line.indexOf('*/');
          if (end == -1) continue;
          line = line.substring(end + 2);
          inBlockComment = false;
        }
        final blockStart = line.indexOf('/*');
        if (blockStart != -1) {
          line = line.substring(0, blockStart);
          inBlockComment = !line.contains('*/');
        }
        final lineComment = line.indexOf('//');
        final code = lineComment == -1 ? line : line.substring(0, lineComment);
        if (code.trim().isEmpty) continue;
        if (lines[i].contains(escapeHatch)) continue;

        if (_rawColor.hasMatch(code)) {
          out.add(
            StyleViolation(
              file: rel,
              line: i + 1,
              kind: 'raw-color',
              text: code,
            ),
          );
        }
        final withoutAllowed = code.replaceAll(_allowedColorsMember, '');
        if (_materialColors.hasMatch(withoutAllowed)) {
          out.add(
            StyleViolation(
              file: rel,
              line: i + 1,
              kind: 'material-colors',
              text: code,
            ),
          );
        }
        if (_bareTextStyle.hasMatch(code)) {
          out.add(
            StyleViolation(
              file: rel,
              line: i + 1,
              kind: 'bare-textstyle',
              text: code,
            ),
          );
        }
      }
    }
    return out;
  }

  /// Every way of naming an amber token.
  ///
  /// `flame*` plus the three that are amber without the word in their name:
  /// the ink that goes ON an amber block, the pressed fill, and the gradient
  /// stops every bloom is made of.
  static final RegExp _amberToken = RegExp(
    r'(?<![A-Za-z0-9_$])'
    r'(flame(300|500|600|700|900)|glowAmber|amberPressed|onAmberPressed|onAmber)'
    r'(?![A-Za-z0-9_$])',
  );

  /// Files that are allowed to name an amber token.
  ///
  /// Amber is emitted light and the ladder decides who emits it. A widget
  /// that reaches for `flame600` directly has not asked [TorchScope] whether
  /// it is lit, which means it is lit on every route including the ones with
  /// two other lights on them — and the pixel census will then fail on a
  /// screen whose own code looks innocent.
  ///
  /// Adding a path here is adding an emitter to the system. It is a design
  /// decision, and it should be argued in the PR that adds it.
  static const Set<String> amberAllowlist = <String>{
    // The token source itself, and the one place the old shims map onto it.
    'core/theme/torchlight/tiq_palette.dart',
    'core/theme/torchlight/tiq_skin.dart',
    'core/theme/torchlight/tiq_contrast.dart',
    'core/theme/tiq_colors.dart',
    'core/theme/app_theme.dart',
    // Phase 1, the chrome and the button family. Four emitters, and every one
    // of them asks TorchScope before it lights anything:
    //
    //   primary_button  the rim and the 2dp bleed in Night, the block in
    //                   Day and Veld — TorchClaim.primaryCommit, rung 1.
    //   nav_pill        the active tab in Night — TorchScope.navActiveTabId,
    //                   which the allocator grants itself, counted not exempt.
    //   nav_circle      the standing action — TorchClaim.navCircle, rung 4,
    //                   and denied outright on any route with a primary.
    //   torch_press     the keyboard focus ring, which is flame-700 in Night
    //                   and ink in Day and Veld. It is the one amber the
    //                   ladder does not count, by declaration: it renders only
    //                   under FocusHighlightMode.traditional, so it never
    //                   co-occurs with the touch frame the census measures.
    'core/widgets/torchlight/button/primary_button.dart',
    'core/widgets/torchlight/button/torch_press.dart',
    'core/widgets/torchlight/chrome/nav_circle.dart',
    'core/widgets/torchlight/chrome/nav_pill.dart',
    // Phase 1, the plate. The fifth emitter, and the only one that is not a
    // control:
    //
    //   plate           the strip light — a 2px flame-600 line and the 48dp
    //                   gradient bloom above it, counted as ONE object because
    //                   that is what it looks like. TorchClaim.plateStripLight,
    //                   rung 2. It asks TorchScope like the rest, and then
    //                   declines the grant anyway when there is no photograph:
    //                   a light needs something to be a light *on*, and a lit
    //                   drawing is a decoration wearing the screen's one light.
    //
    // Note what is NOT here. `plate_fallback.dart` draws the no-photograph
    // state and never names a flame token in any skin or state, which is the
    // rule rather than an implementation detail.
    'core/widgets/torchlight/plate/plate.dart',
    // Phase 1, the agent screens. The sixth emitter, and the only claimant of
    // rung 6 on this surface:
    //
    //   check_in_radar  the leading ring while a GPS fix is being sought —
    //                   TorchClaim.livePulse. unify §1.1 rules that the pulse
    //                   means PRESENCE and never progress, and names looking
    //                   for a fix as one of the four places it is allowed. The
    //                   trailing ring is chart-neutral and the pin sits inside
    //                   the lit ring's bounds, so the pair is one object. It
    //                   goes out on every light ground, where the light source
    //                   outside is the sun.
    'core/widgets/torchlight/check_in_radar.dart',
  };

  /// Scan [root] (expected to be `lib/`) for amber tokens named outside the
  /// allowlist.
  static List<StyleViolation> scanAmber(Directory root) {
    final out = <StyleViolation>[];
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final rel = _relative(file.path, root.path);
      if (amberAllowlist.contains(rel)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        if (raw.contains(escapeHatch)) continue;
        final lineComment = raw.indexOf('//');
        final code = lineComment == -1 ? raw : raw.substring(0, lineComment);
        if (_amberToken.hasMatch(code)) {
          out.add(
            StyleViolation(
              file: rel,
              line: i + 1,
              kind: 'amber-outside-allowlist',
              text: code,
            ),
          );
        }
      }
    }
    return out;
  }

  static Map<String, int> countByFile(List<StyleViolation> violations) {
    final counts = <String, int>{};
    for (final v in violations) {
      counts[v.file] = (counts[v.file] ?? 0) + 1;
    }
    return counts;
  }

  static String _relative(String path, String rootPath) {
    final normalisedRoot = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';
    final rel = path.startsWith(normalisedRoot)
        ? path.substring(normalisedRoot.length)
        : path;
    return rel.replaceAll(Platform.pathSeparator, '/');
  }
}
