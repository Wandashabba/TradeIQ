import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/section_form.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

/// THE GRAMMAR ITSELF — the furniture every section shares, exercised once on
/// a minimal section so a failure here names the grammar and not a screen.

/// One toggle, one Save, a skip target, and a switchable failure.
class _Probe extends StatefulWidget {
  const _Probe({this.failSave = false, this.onSaved, this.hold});

  final bool failSave;
  final VoidCallback? onSaved;

  /// Holds the save open, so a test can sit on the `saving` frame.
  final Completer<void>? hold;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  bool _on = false;
  bool _dirty = false;

  Future<void> _save() async {
    final hold = widget.hold;
    if (hold != null) await hold.future;
    if (widget.failSave) throw StateError('the outbox refused');
    widget.onSaved?.call();
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) => SectionForm(
    title: 'Probe',
    phase: 'probe',
    dirty: _dirty,
    onSave: _save,
    savedLine: 'Probe saved',
    skip: const SectionSkipTarget('v1', AuditSection.competitive),
    children: <Widget>[
      SectionFieldGroup(
        title: 'Group',
        children: <Widget>[
          TorchToggle(
            key: const ValueKey<String>('probe-toggle'),
            label: 'Something',
            value: _on,
            onWord: 'Yes',
            offWord: 'No',
            onChanged: (v) => setState(() {
              _on = v;
              _dirty = true;
            }),
          ),
        ],
      ),
    ],
  );
}

/// A hub stand-in that pushes the section, so leaving has somewhere to go.
class _Host extends StatelessWidget {
  const _Host({required this.section});

  final Widget section;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF000000),
    child: Center(
      child: GestureDetector(
        key: const ValueKey<String>('open'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => section)),
        child: const SizedBox(width: 100, height: 100),
      ),
    ),
  );
}

Finder _key(String k) => find.byKey(ValueKey<String>(k));

/// Tap inside an open sheet, bringing the target into view first: a sheet
/// scrolls, and a tap that lands off-screen misses silently — leaving the
/// sheet open, and the app-wide open-sheet count wrong for every later test.
Future<void> _tapInSheet(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, Widget section) async {
  await pumpSection(tester, _Host(section: section));
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('leaving', () {
    testWidgets('a clean section leaves silently', (tester) async {
      await _open(tester, const _Probe());
      final back = find.byWidgetPredicate(
        (w) => w is TorchIconButton && w.icon == Icons.arrow_back,
      );
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('Probe'), findsNothing);
      await disposeAgentScreen(tester);
    });

    testWidgets('a dirty one asks, in three unequal rows — and Stay keeps '
        'everything', (tester) async {
      var saves = 0;
      await _open(tester, _Probe(onSaved: () => saves++));
      await tapInSection(tester, _key('probe-toggle'));

      final back = find.byWidgetPredicate(
        (w) => w is TorchIconButton && w.icon == Icons.arrow_back,
      );
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('You have unsaved answers'), findsOneWidget);
      expect(_key('leave-save'), findsOneWidget);
      expect(_key('leave-discard'), findsOneWidget);
      expect(_key('leave-stay'), findsOneWidget);
      // Save is the one primary; Discard is never its equal.
      expect(tester.widget(_key('leave-save')), isA<TorchPrimaryButton>());
      expect(tester.widget(_key('leave-discard')), isA<TorchSecondaryButton>());

      await tester.tap(_key('leave-stay'));
      await tester.pumpAndSettle();
      expect(find.text('Probe'), findsOneWidget);
      expect(saves, 0);

      await tester.tap(back);
      await tester.pumpAndSettle();
      await tester.tap(_key('leave-save'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('Probe'), findsNothing);
      await disposeAgentScreen(tester);
    });

    testWidgets('going back without saving saves nothing', (tester) async {
      var saves = 0;
      await _open(tester, _Probe(onSaved: () => saves++));
      await tapInSection(tester, _key('probe-toggle'));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TorchIconButton && w.icon == Icons.arrow_back,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_key('leave-discard'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.text('Probe'), findsNothing);
      await disposeAgentScreen(tester);
    });

    for (final skin in agentSkinModes) {
      testWidgets('the leave sheet is the one lit object — ${skin.name}', (
        tester,
      ) async {
        await pumpSection(tester, _Host(section: const _Probe()), skin: skin);
        await tester.tap(_key('open'));
        await tester.pumpAndSettle();
        await tapInSection(tester, _key('probe-toggle'));
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is TorchIconButton && w.icon == Icons.arrow_back,
          ),
        );
        await tester.pumpAndSettle();
        // The armed Save beneath is extinguished while the sheet is up.
        await expectAmber(
          tester,
          skin: skin,
          route: 'section / leaving dirty',
          phase: 'sheet',
          expected: 1,
        );
        await tester.tap(_key('leave-stay'));
        await tester.pumpAndSettle();
        await disposeAgentScreen(tester);
      });
    }

    // THE WAY OUT MOST AGENTS ACTUALLY USE. Android's back button and the iOS
    // back swipe both arrive on the platform pop channel, not on the header's
    // arrow — so a guard wired only to the arrow loses a half-counted shelf on
    // the gesture, silently, with the sheet never rendering. Every test above
    // taps the arrow, which is exactly why this one drives the channel.
    testWidgets('the system back button gets the same sheet as the arrow, and '
        'the section is still there', (tester) async {
      var saves = 0;
      await _open(tester, _Probe(onSaved: () => saves++));
      await tapInSection(tester, _key('probe-toggle'));

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        handled,
        isTrue,
        reason: 'the platform pop is answered by the app, not the OS',
      );
      expect(find.text('You have unsaved answers'), findsOneWidget);
      expect(_key('leave-save'), findsOneWidget);
      expect(_key('leave-discard'), findsOneWidget);
      expect(_key('leave-stay'), findsOneWidget);
      // The sheet names the section too, so the title is no longer unique —
      // the answers themselves are what must still be here.
      expect(
        _key('probe-toggle'),
        findsOneWidget,
        reason: 'the section is still on screen with its answers in it',
      );
      expect(tester.widget<TorchToggle>(_key('probe-toggle')).value, isTrue);

      // Stay keeps everything, and a second system back asks again.
      await tester.tap(_key('leave-stay'));
      await tester.pumpAndSettle();
      expect(find.text('Probe'), findsOneWidget);
      expect(saves, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // Discard leaves for real: the imperative pop is not refused a second
      // time by the guard that opened the sheet.
      await tester.tap(_key('leave-discard'));
      await tester.pumpAndSettle();
      expect(find.text('Probe'), findsNothing);
      expect(saves, 0);
      await disposeAgentScreen(tester);
    });

    testWidgets('a clean section still leaves on the system back', (
      tester,
    ) async {
      await _open(tester, const _Probe());
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.text('You have unsaved answers'), findsNothing);
      expect(find.text('Probe'), findsNothing);
      await disposeAgentScreen(tester);
    });

    testWidgets("a can't-confirm section leaves on the system back without "
        'asking — there is nothing to lose', (tester) async {
      await _open(tester, const _Probe());
      await tapInSection(tester, _key('probe-toggle'));
      await tapInSection(tester, _key('section-cant-confirm'));
      await _tapInSheet(tester, find.text('They do not stock this'));
      await _tapInSheet(tester, find.text('Save reason'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('You have unsaved answers'), findsNothing);
      expect(find.text('Probe'), findsNothing);
      await disposeAgentScreen(tester);
    });
  });

  group('the save cycle', () {
    testWidgets('a failed save keeps the answers and says so; Save is the '
        'retry', (tester) async {
      await pumpSection(tester, const _Probe(failSave: true));
      await tapInSection(tester, _key('probe-toggle'));
      await saveSection(tester);

      expect(_key('section-save-failed'), findsOneWidget);
      expect(find.text('Not saved'), findsOneWidget);
      expect(
        find.text('Your answers are still here — try Save again.'),
        findsOneWidget,
      );
      expect(tester.widget<TorchToggle>(_key('probe-toggle')).value, isTrue);
      expect(tester.widget(sectionSave), isA<TorchPrimaryButton>());
      await disposeAgentScreen(tester);
    });

    testWidgets('a saved section says so with a time, and stops asking', (
      tester,
    ) async {
      await pumpSection(tester, const _Probe());
      await tapInSection(tester, _key('probe-toggle'));
      expect(tester.widget(sectionSave), isA<TorchPrimaryButton>());
      await saveSection(tester);
      expect(_key('section-saved'), findsOneWidget);
      expect(find.textContaining('Probe saved · '), findsOneWidget);
      expect(tester.widget(sectionSave), isA<TorchSecondaryButton>());
      await disposeAgentScreen(tester);
    });

    // A save can fail with the form never edited: the untouched Save is a
    // tappable ghost, so `dirty` is still false when the outbox refuses. The
    // retry then renders as the primary commit, and it has to be lit — a
    // denied primary is pixel-for-pixel a dead button, on the one frame where
    // the agent most needs to know they can press it again.
    testWidgets('a save that fails without an edit still renders a retry, and '
        'it is lit', (tester) async {
      await pumpSection(
        tester,
        const _Probe(failSave: true),
        skin: SkinMode.day,
      );
      await saveSection(tester);

      expect(_key('section-save-failed'), findsOneWidget);
      expect(tester.widget(sectionSave), isA<TorchPrimaryButton>());
      await expectAmber(
        tester,
        skin: SkinMode.day,
        route: 'section / the save cycle',
        phase: 'failed, never edited',
        expected: 1,
      );
      await disposeAgentScreen(tester);
    });
  });

  // The brief asks for a census per phase × skin. `untouched`, `dirty`,
  // `locked` and `sheet` were covered; `saving` and `failed` were not, in any
  // skin, on any route — and `failed` was the one that was wrong.
  group('the amber census, the whole save cycle', () {
    for (final skin in agentSkinModes) {
      testWidgets('saving holds the one object — ${skin.name}', (tester) async {
        final hold = Completer<void>();
        await pumpSection(tester, _Probe(hold: hold), skin: skin);
        await tapInSection(tester, _key('probe-toggle'));
        await tester.tap(sectionSave);
        await tester.pump();

        expect(tester.widget<TorchPrimaryButton>(sectionSave).busy, isTrue);
        await expectAmber(
          tester,
          skin: skin,
          route: 'section / save cycle',
          phase: 'saving',
          expected: 1,
        );
        hold.complete();
        await tester.pumpAndSettle();
        await disposeAgentScreen(tester);
      });

      testWidgets('failed keeps the one object — ${skin.name}', (tester) async {
        await pumpSection(tester, const _Probe(failSave: true), skin: skin);
        await tapInSection(tester, _key('probe-toggle'));
        await saveSection(tester);
        expect(_key('section-save-failed'), findsOneWidget);
        await expectAmber(
          tester,
          skin: skin,
          route: 'section / save cycle',
          phase: 'failed',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });

  group("can't confirm", () {
    Future<void> skip(WidgetTester tester, String reason) async {
      await tapInSection(tester, _key('section-cant-confirm'));
      expect(_key('section-skip-picker'), findsOneWidget);
      await _tapInSheet(tester, find.text(reason));
      await _tapInSheet(tester, find.text('Save reason'));
    }

    testWidgets('the picker offers the reasons, says what it produces, and '
        'locks the section with the reason in words', (tester) async {
      await pumpSection(tester, const _Probe());
      await tapInSection(tester, _key('section-cant-confirm'));

      expect(find.text('Why not?'), findsOneWidget);
      expect(find.text('The store would not let me'), findsOneWidget);
      expect(find.text('They do not stock this'), findsOneWidget);
      // No consequence the wire cannot keep, and the one true sentence.
      expect(find.text('The manager is told the store refused'), findsNothing);
      expect(
        find.text('Held on this phone. Nothing is sent for this yet.'),
        findsOneWidget,
      );
      await _tapInSheet(tester, find.text('They do not stock this'));
      await _tapInSheet(tester, find.text('Save reason'));

      expect(_key('section-cant-confirm-line'), findsOneWidget);
      expect(
        find.text("Can't confirm: They do not stock this"),
        findsOneWidget,
      );
      // Locked: no Save, and the thumb zone's commit says why it will not.
      expect(sectionSave, findsNothing);
      final ghost = tester.widget<TorchSecondaryButton>(
        _key('section-save-and-back'),
      );
      expect(ghost.onPressed, isNull);
      expect(ghost.blockedReason, "This section is marked can't confirm");

      await tapInSection(tester, _key('section-can-confirm'));
      expect(_key('section-cant-confirm-line'), findsNothing);
      expect(sectionSave, findsOneWidget);
      await disposeAgentScreen(tester);
    });

    testWidgets('dismissing the picker records nothing', (tester) async {
      await pumpSection(tester, const _Probe());
      await tapInSection(tester, _key('section-cant-confirm'));
      await _tapInSheet(tester, find.text('Cancel'));
      expect(_key('section-skip-picker'), findsNothing);
      expect(_key('section-cant-confirm-line'), findsNothing);
      expect(sectionSave, findsOneWidget);
      await disposeAgentScreen(tester);
    });

    testWidgets('the picker speaks Afrikaans', (tester) async {
      await pumpSection(tester, const _Probe(), locale: const Locale('af'));
      await tapInSection(tester, _key('section-cant-confirm'));
      expect(find.text('Hulle hou dit nie aan nie'), findsOneWidget);
      expect(find.text('They do not stock this'), findsNothing);
      await _tapInSheet(tester, find.text('Hulle hou dit nie aan nie'));
      await _tapInSheet(tester, find.text('Stoor rede'));
      expect(_key('section-cant-confirm-line'), findsOneWidget);
      await disposeAgentScreen(tester);
    });

    for (final skin in agentSkinModes) {
      testWidgets('a locked section is dark — ${skin.name}', (tester) async {
        await pumpSection(tester, const _Probe(), skin: skin);
        await tapInSection(tester, _key('probe-toggle'));
        await skip(tester, 'The equipment is broken');
        await expectAmber(
          tester,
          skin: skin,
          route: 'section / cant-confirm',
          phase: 'locked',
          expected: 0,
        );
        await disposeAgentScreen(tester);
      });
    }
  });

  group('Veld is built, not declared', () {
    testWidgets('every control in a section is at least 56dp', (tester) async {
      await pumpSection(tester, const _Probe(), skin: SkinMode.veld);
      await tapInSection(tester, _key('probe-toggle'));
      await scrollAgentTo(tester, sectionSave);
      for (final finder in <Finder>[
        sectionSave,
        _key('section-cant-confirm'),
        _key('section-save-and-back'),
        _key('probe-toggle'),
      ]) {
        expect(
          tester.getSize(finder).height,
          greaterThanOrEqualTo(56),
          reason: '$finder in Veld',
        );
      }
      await disposeAgentScreen(tester);
    });
  });
}
