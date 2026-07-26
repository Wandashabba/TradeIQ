import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/status_pill_colors.dart';

import 'tiq_colors_test.dart' show contrastRatio;

void main() {
  group('status pill wash pairs', () {
    // The single source of truth for the good/warn/bad status washes. Values
    // are frozen — a slipped hex fails loudly here and in the consumers' pinned
    // colour tests.
    test('each pair carries today\'s exact wash/text hexes', () {
      expect(statusPillGood.bg, const Color(0xFFE7F5E7));
      expect(statusPillGood.fg, const Color(0xFF0B6B0B));
      expect(statusPillWarn.bg, const Color(0xFFFDF3E2));
      expect(statusPillWarn.fg, const Color(0xFF8A5A00));
      expect(statusPillBad.bg, const Color(0xFFFDEEEE));
      expect(statusPillBad.fg, const Color(0xFFA52A2A));
    });

    // These are FIXED status washes (not theme tokens): a self-contained pair
    // whose text clears WCAG AA 4.5:1 on its own wash, the same in both themes.
    // That self-containment is the whole reason they are hexes, so guard it.
    for (final entry in <String, StatusPillWash>{
      'good': statusPillGood,
      'warn': statusPillWarn,
      'bad': statusPillBad,
    }.entries) {
      test('${entry.key} text clears 4.5:1 on its own wash', () {
        final ratio = contrastRatio(entry.value.fg, entry.value.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${entry.key} is $ratio:1 — a status wash must read its own '
              'text at AA on its own, in both themes.',
        );
      });
    }
  });

  test('the literal wash hexes live only in the shared source', () {
    // Grep-guard: the six wash hexes must appear in NO consumer file — they are
    // single-sourced in status_pill_colors.dart. If one reappears, a consumer
    // has re-inlined a value that can now drift.
    const hexes = [
      '0xFFE7F5E7',
      '0xFF0B6B0B',
      '0xFFFDF3E2',
      '0xFF8A5A00',
      '0xFFFDEEEE',
      '0xFFA52A2A',
    ];
    const consumers = [
      'lib/core/widgets/delta_pill.dart',
      'lib/core/widgets/sla_pill.dart',
      'lib/core/widgets/agent_kit.dart',
      'lib/features/beatplans/presentation/today_screen.dart',
    ];
    for (final path in consumers) {
      final src = File(path).readAsStringSync();
      final offenders = hexes.where(src.contains).toList();
      expect(
        offenders,
        isEmpty,
        reason:
            '$path re-inlines status-pill hexes $offenders — reference '
            'status_pill_colors.dart instead.',
      );
    }
  });
}
