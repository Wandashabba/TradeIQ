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
