import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';

import 'phase2_harness.dart';

void main() {
  group('the skeleton', () {
    testWidgets('renders nothing for the first 600ms', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const Skeleton(label: 'outlets', child: SkeletonRows()),
      );
      expect(
        find.byType(SkeletonShell),
        findsNothing,
        reason:
            'Most loads finish inside 600ms, and a skeleton that flashes for '
            '200ms is worse than a blank frame.',
      );

      await tester.pump(Skeleton.appearsAfter);
      expect(find.byType(SkeletonShell), findsWidgets);
    });

    testWidgets('fills its text blocks with edge-structure in Night, not the '
        'well', (tester) async {
      final night = TiqSkin.night(density: TiqDensity.field);
      expect(
        SkeletonLine.fillFor(night),
        night.palette.edgeStructure,
        reason:
            'well #141D27 on ground #0B1017 is 1.12:1 — the ratio the device '
            'floor forbids. An agent on 3G watching a list load for four '
            'seconds saw a black screen and assumed the app had broken.',
      );
      // Day's well works on paper, so it keeps it.
      expect(SkeletonLine.fillFor(TiqSkin.day()), TiqSkin.day().palette.well);
    });

    testWidgets('travels an Oatmeal rule, never an amber one', (tester) async {
      // The colour is asserted by the census; what matters here is the token
      // the loop is declared against and that the timing is the shared one.
      expect(Skeleton.travel, TiqMotion.skeleton);
      expect(Skeleton.travel, const Duration(milliseconds: 1400));
      expect(Skeleton.ruleThickness, 2);
    });

    testWidgets('is the word "Loading" in Veld, and nothing else', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.veld(),
        child: const Skeleton(label: 'outlets', child: SkeletonRows()),
      );
      expect(find.text('Loading'), findsOneWidget);
      expect(
        find.byType(SkeletonShell),
        findsNothing,
        reason:
            'A field of grey blocks on white at 40% backlight in the sun is '
            'indistinguishable from a broken screen.',
      );
    });

    testWidgets('says so when it is slower than usual', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const Skeleton(
          label: 'outlets',
          slowLine: 'Still fetching · this is slower than usual',
          child: SkeletonRows(),
        ),
      );
      await tester.pump(Skeleton.appearsAfter);
      expect(
        find.text('Still fetching · this is slower than usual'),
        findsNothing,
      );
      await tester.pump(Skeleton.slowAfter);
      expect(
        find.text('Still fetching · this is slower than usual'),
        findsOneWidget,
      );
    });
  });

  group('the empty state', () {
    testWidgets('carries a drawing whole-screen and none in a panel', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const EmptyState(
          drawing: EmptyDrawing.shelf,
          headline: 'No outlets within 2 km',
        ),
      );
      expect(find.byType(EmptyStateDrawing), findsOneWidget);

      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const EmptyState(
          scope: EmptyScope.inPanel,
          headline: 'Nothing triaged yet',
        ),
      );
      expect(
        find.byType(EmptyStateDrawing),
        findsNothing,
        reason:
            'A 64dp illustration inside a 200dp panel is a decoration '
            'competing with the sentence beside it.',
      );
    });

    testWidgets('refuses a drawing in a panel at construction', (tester) async {
      expect(
        () => EmptyState(
          scope: EmptyScope.inPanel,
          headline: 'Nothing here',
          drawing: EmptyDrawing.pin,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('has exactly three drawings, and the enum is the guard', (
      tester,
    ) async {
      expect(
        EmptyDrawing.values,
        <EmptyDrawing>[
          EmptyDrawing.shelf,
          EmptyDrawing.pin,
          EmptyDrawing.envelope,
        ],
        reason:
            'A fourth requires an owner decision and an illustrator, not an '
            'import. Eight bespoke drawings nobody commissions becomes a '
            'stock outline set, which is the slop this enum exists to refuse.',
      );
    });

    testWidgets('scales the placeholder down in Veld', (tester) async {
      expect(EmptyStateDrawing.extentFor(TiqSkin.night()), 64);
      expect(EmptyStateDrawing.extentFor(TiqSkin.veld()), 48);
      expect(EmptyStateDrawing.strokeFor(TiqSkin.veld()), 3);
    });
  });

  group('the error state', () {
    test('never puts a raw exception in front of a user', () {
      final message = TorchErrorMessage.sanitise(
        StateError("Failed host lookup: 'api.tradeiq.co.za'"),
        status: 503,
      );
      expect(message.kind, TorchErrorKind.server);
      expect(message.headline, isNot(contains('api.tradeiq')));
      expect(message.body, isNot(contains('StateError')));
      expect(message.code, 'HTTP 503');
      expect(
        message.body,
        contains('held on this phone'),
        reason:
            "The body names the work's safety first. That is the sentence an "
            'agent with six captured sections needs before anything else.',
      );
    });

    test('offers a Retry only where retrying is honest', () {
      expect(
        TorchErrorMessage.forKind(TorchErrorKind.network).offersRetry,
        isFalse,
        reason: 'A retry with no signal is theatre.',
      );
      expect(
        TorchErrorMessage.forKind(TorchErrorKind.rejected).offersRetry,
        isFalse,
        reason: 'Retrying an unchanged rejection fails identically.',
      );
      expect(
        TorchErrorMessage.forKind(TorchErrorKind.permission).offersRetry,
        isFalse,
      );
      expect(
        TorchErrorMessage.forKind(TorchErrorKind.server).offersRetry,
        isTrue,
      );
    });

    test('maps a status onto a kind in one place', () {
      expect(TorchErrorMessage.kindForStatus(413), TorchErrorKind.tooLarge);
      expect(TorchErrorMessage.kindForStatus(401), TorchErrorKind.permission);
      expect(TorchErrorMessage.kindForStatus(403), TorchErrorKind.permission);
      expect(TorchErrorMessage.kindForStatus(422), TorchErrorKind.rejected);
      expect(TorchErrorMessage.kindForStatus(500), TorchErrorKind.server);
      expect(TorchErrorMessage.kindForStatus(200), TorchErrorKind.unknown);
    });

    testWidgets('allows one Retry per region and asserts on a second', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: TorchErrorRegion(
          name: 'territory scores',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ErrorState(
                scope: ErrorScope.inline,
                message: TorchErrorMessage.forKind(TorchErrorKind.server),
                action: TorchTertiaryButton(label: 'Retry', onPressed: () {}),
              ),
              ErrorState(
                scope: ErrorScope.inline,
                message: TorchErrorMessage.forKind(TorchErrorKind.server),
                action: TorchTertiaryButton(label: 'Retry', onPressed: () {}),
              ),
            ],
          ),
        ),
      );
      expect(
        tester.takeException(),
        isNotNull,
        reason:
            'Two buttons that do the same thing is a user pressing both and a '
            'request firing twice.',
      );
    });

    testWidgets('drops the support code in Veld', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.veld(),
        child: ErrorState(
          message: TorchErrorMessage.forKind(
            TorchErrorKind.server,
            code: 'HTTP 503',
          ),
        ),
      );
      expect(
        find.text('HTTP 503'),
        findsNothing,
        reason:
            'A support code is unreadable in glare and useless to an agent on '
            'a shelf.',
      );
    });

    testWidgets('states the count rather than repeating itself', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: ErrorState(
          scope: ErrorScope.inline,
          message: TorchErrorMessage.forKind(TorchErrorKind.server),
          attempts: 3,
        ),
      );
      expect(find.text('Tried 3 times'), findsOneWidget);
    });
  });

  group('the held / offline banner', () {
    testWidgets('paints held in Oatmeal, and only needs-you raises a colour', (
      tester,
    ) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      final held = SyncStateToken.of(skin, SyncState.held);
      expect(
        held.ink,
        skin.palette.ink2,
        reason:
            'Working offline is the normal state of South African field work, '
            'not a fault. Towers go down with the grid and "12 held" is a '
            'normal Tuesday.',
      );
      expect(
        held.ink,
        isNot(skin.palette.comparison),
        reason:
            'Truffle is the comparison series and nothing else. Giving it a '
            'second meaning is the failure the severity system avoids.',
      );
      expect(held.leadingBar, isNull);

      for (final state in SyncState.values) {
        final token = SyncStateToken.of(skin, state);
        if (state == SyncState.needsYou) {
          expect(token.leadingBar, skin.palette.badSolid);
          expect(token.ink, skin.palette.bad);
        } else {
          expect(
            token.leadingBar,
            isNull,
            reason: '${state.name} must not raise a colour.',
          );
          expect(token.ink, isNot(skin.palette.bad));
        }
      }
    });

    testWidgets('gives every state the same height so content never jumps', (
      tester,
    ) async {
      expect(OfflineHeldBanner.heightFor(TiqSkin.night()), 56);
      expect(OfflineHeldBanner.heightFor(TiqSkin.veld()), 72);
    });

    testWidgets('keeps the count out of the live label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: OfflineHeldBanner(
          state: SyncState.held,
          count: 12,
          label: 'held on this phone',
          onTap: () {},
        ),
      );
      // The count is the node's VALUE, read on focus. In the live label it
      // interrupted an agent mid-capture twelve times a visit — the worst
      // accessibility bug the kit had, during the one workflow where an
      // interruption loses data.
      final node = tester.getSemantics(find.byType(OfflineHeldBanner));
      expect(node.label, contains('tap to open your work'));
      expect(node.value, contains('12'));
      expect(
        node.label,
        isNot(contains('12')),
        reason:
            'The count animates. A count inside a live label is an '
            'announcement every time it changes.',
      );
      handle.dispose();
    });

    testWidgets('has six distinct silhouettes', (tester) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      final shapes = SyncState.values
          .map((s) => SyncStateToken.of(skin, s).shape)
          .toList();
      expect(
        shapes.toSet().length,
        greaterThanOrEqualTo(5),
        reason:
            'Every state has to be distinguishable in greyscale. Sending and '
            'held share a square by design — the pulse is the difference, and '
            'it degrades to the word.',
      );
    });
  });

  group('the progress bar', () {
    testWidgets('states the fraction as text, always', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchProgressBar(
          label: 'Visits today',
          value: 0,
          total: 9,
        ),
      );
      expect(
        find.text('0 of 9'),
        findsOneWidget,
        reason:
            'Zero progress is information. The bar is never the only '
            'statement of progress.',
      );
    });

    testWidgets('replaces the fraction with the word when it is done', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchProgressBar(
          label: 'Visits today',
          value: 9,
          total: 9,
          doneWord: 'Done',
        ),
      );
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('never invents a denominator', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchProgressBar(
          label: 'Sending',
          value: 3,
          workingWord: 'Working',
        ),
      );
      expect(find.text('Working'), findsOneWidget);
    });

    testWidgets('is the word "Working" in Veld, with no travelling rule', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.veld(),
        child: const TorchProgressBar(label: 'Sending', workingWord: 'Working'),
      );
      expect(find.text('Working'), findsWidgets);
    });

    testWidgets('scales its track at half rate and stops at 12', (
      tester,
    ) async {
      late double one;
      late double two;
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: Builder(
          builder: (context) {
            one = TorchProgressBar.trackHeightFor(context);
            return const SizedBox.shrink();
          },
        ),
      );
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        textScale: 2.0,
        child: Builder(
          builder: (context) {
            two = TorchProgressBar.trackHeightFor(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(one, 8);
      expect(two, 12, reason: 'A track is a graphic and scales at half rate.');
    });
  });

  group('the toast', () {
    testWidgets('floats above the nav pill', (tester) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      final withNav = TorchToast.bottomOffsetFor(skin);
      final withoutNav = TorchToast.bottomOffsetFor(
        skin,
        navRenders: false,
        thumbZoneHeight: 96,
      );
      expect(
        withNav,
        greaterThan(64),
        reason:
            'The pill is 64 tall and stands 20dp off the safe area; a toast '
            'that covers the primary commit action is a toast about a thing '
            'you can no longer press.',
      );
      expect(withoutNav, 96 + 20);
    });

    testWidgets('gives a failure twice the dwell', (tester) async {
      expect(
        TorchToast.dwellFor(ToastKind.neutral, hasAction: false),
        const Duration(seconds: 3),
      );
      expect(
        TorchToast.dwellFor(ToastKind.failure, hasAction: false),
        const Duration(seconds: 6),
      );
      expect(
        TorchToast.dwellFor(ToastKind.success, hasAction: true),
        const Duration(seconds: 6),
      );
    });

    testWidgets('treats held as a fact, not a failure', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchToast(
          message: 'Held on this phone · sends itself',
          kind: ToastKind.held,
        ),
      );
      expect(find.text('Held on this phone · sends itself'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the pagination footer', () {
    testWidgets('says what was cut, and carries the unscored note', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(),
        child: const PaginationFooter(
          summary: 'Showing the 20 riskiest of 74.',
          narrowLine: 'Narrow by territory to see the rest.',
          unscoredNote:
              '6 submitted visits have not been scored yet and are not '
              'listed here.',
        ),
      );
      expect(find.text('Showing the 20 riskiest of 74.'), findsOneWidget);
      expect(
        find.textContaining('have not been scored yet'),
        findsOneWidget,
        reason:
            'An unscored visit is not a clean one, and a short list of the '
            'riskiest twenty must never read as "nothing suspicious".',
      );
      expect(PaginationFooter.heightFor(TiqSkin.night()), 44);
      expect(PaginationFooter.heightFor(TiqSkin.veld()), 64);
    });

    // The footer's words are one utterance, and its action used to be INSIDE
    // that utterance's `excludeSemantics` — painted, hit-testable and
    // announced nowhere. Same defect as the button family's, in the footer.
    testWidgets('an action keeps its own node', (tester) async {
      var tapped = false;
      final handle = tester.ensureSemantics();
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(),
        child: PaginationFooter(
          summary: 'Showing the 20 riskiest of 74.',
          action: TorchTertiaryButton(
            label: 'Narrow this',
            onPressed: () => tapped = true,
          ),
        ),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('Narrow this'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(tapped, isTrue);
      handle.dispose();
    });
  });
}
