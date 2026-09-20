import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

// ── The a11y guard ────────────────────────────────────────────────────
//
// The kit once shipped a whole component family that announced itself as a
// button and did nothing when a screen reader activated it. This is the guard
// for that law, in one place: the territory group wrote it, the operations
// group needed the same thing on nine more screens, and a law with two copies
// is a law that drifts.

/// Every semantics node under the pumped tree, root first.
List<SemanticsNode> semanticsNodes(WidgetTester tester, {Finder? from}) {
  SemanticsNode root = tester.getSemantics(from ?? find.byType(MaterialApp));
  while (root.parent != null) {
    root = root.parent!;
  }
  final out = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    out.add(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return out;
}

/// `BUTTON label="…" tap=true` per node — the dump a failure prints, so the
/// reason is readable without a debugger.
String semanticsDump(WidgetTester tester, {Finder? from}) =>
    semanticsNodes(tester, from: from)
        .map((n) => n.getSemanticsData())
        .where((d) => d.label.isNotEmpty || d.actions != 0)
        .map(
          (d) =>
              '${d.flagsCollection.isButton ? 'BUTTON' : 'node'} '
              'label="${d.label}" '
              'tap=${d.hasAction(SemanticsAction.tap)}',
        )
        .join('\n');

/// THE LAW: a node that announces itself as a button, and is not announced as
/// disabled, carries [SemanticsAction.tap].
///
/// A `Semantics(button: true, …, excludeSemantics: true)` around a
/// `GestureDetector` drops the descendant's node and declares a button with no
/// action on it. It reads correct in the source and is inert in the hand —
/// which is how the whole component kit shipped unpressable once, and how
/// `SectionRuleAction` and `PaginationFooter.action` were still shipping when
/// the operations group wrote its census tests.
void expectEveryButtonActivatable(WidgetTester tester, {Finder? from}) {
  final inert = <String>[];
  for (final node in semanticsNodes(tester, from: from)) {
    final data = node.getSemanticsData();
    final flags = data.flagsCollection;
    if (!flags.isButton) continue;
    // A disabled control is allowed to have no action — that is what disabled
    // means. An enabled one is not.
    if (flags.isEnabled == Tristate.isFalse) continue;
    if (!data.hasAction(SemanticsAction.tap)) {
      inert.add('"${data.label}"');
    }
  }
  expect(
    inert,
    isEmpty,
    reason:
        'These announce as buttons and cannot be activated: '
        '${inert.join(', ')}\n\n${semanticsDump(tester, from: from)}',
  );
}
