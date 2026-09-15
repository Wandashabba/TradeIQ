import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every shipped locale must translate every message in the English template,
/// and keep every placeholder — a missing key silently falls back to English
/// at runtime, and a dropped `{count}` silently drops the number.
Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Iterable<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@'));

void main() {
  final en = _arb('app_en.arb');
  final translations = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.startsWith('app_') && n.endsWith('.arb'))
      .where((n) => n != 'app_en.arb')
      .toList();

  test('Afrikaans is shipped', () {
    expect(translations, contains('app_af.arb'));
  });

  test('the English template declares a type for every placeholder', () {
    for (final key in _messageKeys(en)) {
      // A placeholder is `{name}` or `{name, plural|select, …}`. A select or
      // plural branch body such as `green{Green}` is copy, not a placeholder —
      // hence the lookbehind excluding a selector just before the brace.
      final used = RegExp(r'(?<![\w=])\{(\w+)(?:\}|,\s*(?:plural|select))')
          .allMatches(en[key] as String)
          .map((m) => m.group(1)!)
          .toSet();
      if (used.isEmpty) continue;
      final meta = en['@$key'] as Map<String, dynamic>?;
      final declared =
          ((meta?['placeholders'] as Map<String, dynamic>?) ?? const {}).keys;
      expect(declared.toSet(), containsAll(used), reason: key);
    }
  });

  for (final file in translations) {
    group(file, () {
      final arb = _arb(file);

      test('has exactly the template\'s message keys', () {
        final missing = _messageKeys(en).toSet().difference(
          _messageKeys(arb).toSet(),
        );
        final extra = _messageKeys(arb).toSet().difference(
          _messageKeys(en).toSet(),
        );
        expect(missing, isEmpty, reason: 'untranslated in $file');
        expect(extra, isEmpty, reason: 'not in app_en.arb');
      });

      test('keeps every placeholder and translates every message', () {
        for (final key in _messageKeys(en)) {
          final meta = en['@$key'] as Map<String, dynamic>?;
          final placeholders =
              (meta?['placeholders'] as Map<String, dynamic>?)?.keys ??
              const <String>[];
          final value = arb[key] as String? ?? '';
          expect(value.trim(), isNotEmpty, reason: key);
          for (final p in placeholders) {
            expect(value, contains('{$p'), reason: '$key drops {$p}');
          }
        }
      });
    });
  }
}
