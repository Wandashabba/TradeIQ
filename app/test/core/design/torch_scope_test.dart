import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// The amber allocator: the arithmetic, the ladder, and both failure modes.
void main() {
  final night = TiqSkin.night();
  final day = TiqSkin.day();
  final veld = TiqSkin.veld();

  group('the budget', () {
    test('Night is two, Day and Veld are one', () {
      expect(TorchScope.budgetFor(night), 2);
      expect(TorchScope.budgetFor(day), 1);
      expect(TorchScope.budgetFor(veld), 1);
    });

    test('the budget follows amberIsInk, not the mode name', () {
      // A fourth skin added later gets the right budget without touching this
      // file, because the question being asked is "is amber light here".
      for (final skin in <TiqSkin>[night, day, veld]) {
        expect(TorchScope.budgetFor(skin), skin.amberIsInk ? 1 : 2);
      }
    });
  });

  group('Night: the nav is counted, not exempt', () {
    test('a tabbed route gets the nav tab plus one content object', () {
      final a = TorchScope.resolve(
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[TorchClaim.primaryCommit('check-in')],
      );
      expect(a.granted.map((c) => c.id), <String>[
        '__nav_active_tab__',
        'check-in',
      ]);
      expect(a.isOverClaimed, isFalse);
    });

    test('an untabbed route gets two content objects', () {
      final a = TorchScope.resolve(
        skin: night,
        navRenders: false,
        tabbedRoute: false,
        claims: <TorchClaim>[
          TorchClaim.plateStripLight('plate'),
          TorchClaim.livePulse('agent'),
        ],
      );
      expect(a.granted.map((c) => c.id), <String>['plate', 'agent']);
      expect(a.denied, isEmpty);
    });

    test('a route cannot forget to count the nav it did not draw', () {
      // The tab is added by the scope, not declared by the view model. "Kit
      // called it reserved and manager called it exempt; both produce the same
      // number and counted is the honest word."
      final a = TorchScope.resolve(
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        claims: const <TorchClaim>[],
      );
      expect(a.granted, hasLength(1));
      expect(a.granted.single.kind, TorchClaimKind.navActiveTab);
    });
  });

  group('the ladder', () {
    TorchAllocation lit(List<TorchClaim> claims, {bool nav = false}) =>
        TorchScope.resolve(
          skin: night,
          navRenders: nav,
          tabbedRoute: nav,
          claims: claims,
        );

    test('primary outranks the plate, which outranks the chart focus', () {
      debugTorchAssertOverClaim = false;
      addTearDown(() => debugTorchAssertOverClaim = true);
      final a = lit(<TorchClaim>[
        TorchClaim.chartFocus('bar'),
        TorchClaim.plateStripLight('plate'),
        TorchClaim.primaryCommit('commit'),
      ]);
      expect(a.granted.map((c) => c.id), <String>['commit', 'plate']);
      expect(a.denied.keys.single.id, 'bar');
      expect(a.denied.values.single, TorchDenial.outranked);
    });

    test('the nav circle only lights on a route with no primary', () {
      final withPrimary = lit(<TorchClaim>[
        TorchClaim.primaryCommit('commit'),
        TorchClaim.navCircle('circle'),
      ]);
      expect(withPrimary.isLit('circle'), isFalse);
      expect(
        withPrimary.denied.entries.single.value,
        TorchDenial.circleWithPrimary,
        reason:
            'The ladder forbids this outright, not merely on budget — the '
            'circle is the standing action, and a screen with a commit action '
            'already has one.',
      );

      final without = lit(<TorchClaim>[TorchClaim.navCircle('circle')]);
      expect(without.isLit('circle'), isTrue);
    });

    test('one live pulse per route, and it is presence not progress', () {
      final a = lit(<TorchClaim>[
        TorchClaim.livePulse('person-row'),
        TorchClaim.livePulse('day-trail'),
      ]);
      expect(a.granted, hasLength(1));
      expect(a.denied.values.single, TorchDenial.duplicatePulse);
    });

    test('the meter tick is not on the ladder at all', () {
      // Figures and manager over kit and agent: a target is an annotation, an
      // annotation is a label, and the tick's silhouette carries it. Ink-1
      // everywhere.
      expect(
        TorchClaimKind.values.map((k) => k.name),
        isNot(contains('meterTick')),
      );
    });

    test('the text-field focus rule is counted, not exempt', () {
      final a = lit(<TorchClaim>[
        TorchClaim.primaryCommit('send'),
        TorchClaim.textFieldFocus('composer'),
      ]);
      expect(
        a.granted.map((c) => c.id),
        <String>['send', 'composer'],
        reason:
            'It fits because the keyboard hides the nav, which returns that '
            'grant to content: a focused field plus a lit primary is exactly '
            'two.',
      );
    });

    test('a claim declared twice is one object', () {
      final a = lit(<TorchClaim>[
        TorchClaim.chartFocus('bar'),
        TorchClaim.chartFocus('bar'),
      ]);
      expect(a.granted, hasLength(1));
      expect(a.denied, isEmpty);
    });
  });

  group('the subject override', () {
    test('one subject jumps the content rungs', () {
      final a = TorchScope.resolve(
        skin: night,
        claims: <TorchClaim>[
          TorchClaim.plateStripLight('plate'),
          TorchClaim.chartFocus('the-bar', subject: true),
        ],
      );
      expect(a.granted.first.id, 'the-bar');
    });

    test('a subject never outranks the nav tab', () {
      final a = TorchScope.resolve(
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[TorchClaim.chartFocus('bar', subject: true)],
      );
      expect(
        a.granted.first.kind,
        TorchClaimKind.navActiveTab,
        reason: 'Chrome that changed colour per route would read as a bug.',
      );
    });

    test('two subjects assert', () {
      expect(
        () => TorchScope.resolve(
          skin: night,
          claims: <TorchClaim>[
            TorchClaim.chartFocus('a', subject: true),
            TorchClaim.plateStripLight('b'),
            const TorchClaim(TorchClaimKind.chartFocus, id: 'c', subject: true),
          ],
        ),
        throwsA(
          isA<FlutterError>().having(
            (e) => e.message,
            'message',
            contains('exactly one `subject`'),
          ),
        ),
      );
    });
  });

  group('light grounds', () {
    test('Day lights the primary and nothing else', () {
      final a = TorchScope.resolve(
        skin: day,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[
          TorchClaim.primaryCommit('commit'),
          TorchClaim.plateStripLight('plate'),
          TorchClaim.chartFocus('bar'),
          TorchClaim.livePulse('agent'),
        ],
      );
      expect(a.granted.map((c) => c.id), <String>['commit']);
      for (final id in <String>['plate', 'bar', 'agent']) {
        expect(
          a.denied.entries.firstWhere((e) => e.key.id == id).value,
          TorchDenial.notAmberOnLightGround,
        );
      }
      expect(
        a.isOverClaimed,
        isFalse,
        reason:
            'Those objects are not over-claiming. They have non-amber forms '
            'on a light ground and they take them — the focus bar is ink-1, '
            'the pulse is a lifted dot and the word Live.',
      );
    });

    test('the nav tab is not counted on a light ground', () {
      // The Day nav-active slot is a solid Abyssal block. Counting it would
      // spend the one grant on chrome that is not amber.
      final a = TorchScope.resolve(
        skin: day,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[TorchClaim.primaryCommit('commit')],
      );
      expect(a.granted.map((c) => c.kind), <TorchClaimKind>[
        TorchClaimKind.primaryCommit,
      ]);
    });

    test('nothing armed means zero amber, not one', () {
      final a = TorchScope.resolve(skin: veld, claims: const <TorchClaim>[]);
      expect(a.granted, isEmpty);
    });

    test('two primaries on a light ground assert', () {
      expect(
        () => TorchScope.resolve(
          skin: day,
          claims: <TorchClaim>[
            TorchClaim.primaryCommit('save'),
            TorchClaim.primaryCommit('submit'),
          ],
        ),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('the sheet rule', () {
    test('every amber beneath an open sheet goes out', () {
      final a = TorchScope.resolve(
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        beneathSheet: true,
        claims: <TorchClaim>[
          TorchClaim.primaryCommit('commit'),
          TorchClaim.plateStripLight('plate'),
        ],
      );
      expect(a.granted, isEmpty);
      expect(
        a.denied.values,
        everyElement(TorchDenial.extinguishedBySheet),
        reason:
            "The nav tab drops to its ink form and the plate's light goes "
            "off, so the sheet's own scope genuinely owns the screen. That is "
            'what lets the scrim stay at 72% and keep the held work visible '
            'behind it.',
      );
      expect(a.isOverClaimed, isFalse);
    });
  });

  group('over-claim: asserts in debug, degrades in release', () {
    test('asserts, with the ladder in the message', () {
      expect(
        () => TorchScope.resolve(
          skin: night,
          navRenders: true,
          tabbedRoute: true,
          claims: <TorchClaim>[
            TorchClaim.primaryCommit('commit'),
            TorchClaim.plateStripLight('plate'),
            TorchClaim.chartFocus('bar'),
          ],
        ),
        throwsA(
          isA<FlutterError>()
              .having(
                (e) => e.message,
                'names the budget',
                contains('budget of 2'),
              )
              .having((e) => e.message, 'prints the ladder', contains('unlit:'))
              .having(
                (e) => e.message,
                'names the override',
                contains('subject: true'),
              ),
        ),
      );
    });

    test('degrades: the surplus loses in ladder order and the frame is lit', () {
      // The release path. A design rule must never throw in front of a user in
      // a back aisle during Stage 6.
      debugTorchAssertOverClaim = false;
      addTearDown(() => debugTorchAssertOverClaim = true);
      final a = TorchScope.resolve(
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[
          TorchClaim.chartFocus('bar'),
          TorchClaim.plateStripLight('plate'),
          TorchClaim.primaryCommit('commit'),
        ],
      );
      expect(a.granted, hasLength(2));
      expect(a.granted.map((c) => c.id), <String>[
        '__nav_active_tab__',
        'commit',
      ]);
      expect(a.overClaimed, 2);
      expect(a.describe(), contains('unlit:'));
    });
  });

  group('as a widget', () {
    Widget wrap(TiqSkin skin, Widget child) => MaterialApp(
      theme: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
      home: child,
    );

    testWidgets('lit() answers for the granted object only', (tester) async {
      final answers = <String, bool>{};
      await tester.pumpWidget(
        wrap(
          night,
          TorchScope(
            skin: night,
            phase: 'loaded',
            navRenders: true,
            tabbedRoute: true,
            claims: <TorchClaim>[TorchClaim.primaryCommit('commit')],
            child: Builder(
              builder: (context) {
                answers['commit'] = TorchScope.lit(context, 'commit');
                answers['plate'] = TorchScope.lit(context, 'plate');
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(answers, <String, bool>{'commit': true, 'plate': false});
    });

    testWidgets('outside a scope, nothing is lit', (tester) async {
      var lit = true;
      await tester.pumpWidget(
        wrap(
          night,
          Builder(
            builder: (context) {
              lit = TorchScope.lit(context, 'anything');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        lit,
        isFalse,
        reason:
            'Unlit is always the safe render — a Phase 1 golden with no route '
            'around it must not paint amber by default.',
      );
      expect(TorchScope.maybeOf, isNotNull);
    });

    test('a rebuild in the same phase notifies nobody', () {
      // Resolution is per route and per declared phase, never per frame: a
      // grant recomputed while the user scrolls is a grant that blinks, and a
      // blinking amber means "happening right now".
      TorchScope at(String phase) => TorchScope(
        skin: night,
        phase: phase,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[TorchClaim.primaryCommit('commit')],
        child: const SizedBox(),
      );
      expect(at('loading').updateShouldNotify(at('loading')), isFalse);
      expect(at('loaded').updateShouldNotify(at('loading')), isTrue);
      expect(
        at('loaded').allocation.granted,
        at('loaded').allocation.granted,
        reason: 'The same inputs produce the same grants, every time.',
      );
    });

    test('opening a sheet notifies, because every amber goes out', () {
      TorchScope at({required bool beneathSheet}) => TorchScope(
        skin: night,
        phase: 'loaded',
        navRenders: true,
        tabbedRoute: true,
        beneathSheet: beneathSheet,
        claims: <TorchClaim>[TorchClaim.primaryCommit('commit')],
        child: const SizedBox(),
      );
      expect(
        at(beneathSheet: true).updateShouldNotify(at(beneathSheet: false)),
        isTrue,
      );
    });
  });
}
