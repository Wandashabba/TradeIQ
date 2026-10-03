import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territories_screen.dart';
import 'package:tradeiq_app/features/territories/presentation/territory_form_screen.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import '../territory_harness.dart';

Future<FakeTerritoriesRepository> _pump(
  WidgetTester tester, {
  Object? createFailure,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Size size = const Size(360, 720),
}) async {
  final repository = FakeTerritoriesRepository(createFailure: createFailure);
  // The form is REACHED, not pumped bare: it pops on success, and a screen
  // that is the only page on the stack pops the navigator empty. Pushing it
  // from the list is also the only way to prove the route is wired.
  await pumpConsole(
    tester,
    const TerritoriesScreen(),
    path: '/territories',
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    extraRoutes: <GoRoute>[
      GoRoute(
        path: '/territories/new',
        builder: (context, state) => const TerritoryFormScreen(),
      ),
    ],
    overrides: <Override>[
      territoriesRepositoryProvider.overrideWithValue(repository),
    ],
  );
  await tester.tap(find.byKey(const ValueKey<String>('territory-create')));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _fill(
  WidgetTester tester, {
  String name = 'Gauteng North',
  String code = 'GP-N',
  String? region,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('territory-name-field')),
    name,
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey<String>('territory-code-field')),
    code,
  );
  await tester.pumpAndSettle();
  if (region != null) {
    await tester.enterText(
      find.byKey(const ValueKey<String>('territory-region-field')),
      region,
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  group('the gate', () {
    // THESE TWO MOVED WITH THE BEHAVIOUR, THEY WERE NOT DELETED.
    //
    // The rule they protect is unchanged — this form never refuses without
    // saying what it wants — and only the *moment* it says it has moved, from
    // before the reader has typed to the press that asks for it. That is the
    // house pattern #515 landed on `/login` and `/account/password`, and the
    // reason is argued there: a dead button that has already told you off is
    // worse than one that answers when you press it.
    //
    // The first assertion was `onPressed, isNull` plus an always-visible
    // reason; it is now a live button, silent on arrival, naming the same two
    // fields in the same words once pressed.
    testWidgets('the commit is live, and says nothing until pressed', (
      tester,
    ) async {
      await _pump(tester);

      final before = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      expect(before.onPressed, isNotNull);
      expect(before.blockedReason, isNull);
      expect(find.text('A name and a code are both required.'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      await tester.pumpAndSettle();

      final after = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      // Still pressable — the reason is an answer, not a refusal.
      expect(after.onPressed, isNotNull);
      expect(after.blockedReason, 'A name and a code are both required.');
      expect(find.text('A name and a code are both required.'), findsOneWidget);
    });

    testWidgets('a name alone is not enough, and the press says so', (
      tester,
    ) async {
      await _pump(tester);
      await _fill(tester, code: '');

      await tester.tap(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      expect(button.blockedReason, 'A name and a code are both required.');
      // And nothing was sent on that press.
      expect(find.text('Gauteng North created.'), findsNothing);
    });

    testWidgets('both fields unlock it', (tester) async {
      await _pump(tester);
      await _fill(tester);

      final button = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      expect(button.onPressed, isNotNull);
      expect(button.blockedReason, isNull);
    });
  });

  group('creating', () {
    testWidgets('sends the trimmed name, code and region', (tester) async {
      final repository = await _pump(tester);
      await _fill(tester, name: '  Gauteng North  ', region: '  Gauteng  ');

      await tester.tap(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repository.createdName, 'Gauteng North');
      expect(repository.createdCode, 'GP-N');
      expect(repository.createdRegion, 'Gauteng');
      expect(find.text('Gauteng North created.'), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets('an empty region is null, never an empty string', (
      tester,
    ) async {
      final repository = await _pump(tester);
      await _fill(tester, region: '   ');

      await tester.tap(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repository.createdRegion, isNull);
      await settleToasts(tester);
    });

    testWidgets('a failure keeps the form and sanitises the message', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        createFailure: Exception('postgres://user:hunter2@db/tradeiq'),
      );
      await _fill(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      await tester.pumpAndSettle();

      expect(repository.createCount, 1);
      expect(find.byType(ErrorState), findsOneWidget);
      // The exception's own toString never reaches the screen: a message that
      // is sometimes an exception one day carries a host name into a
      // screenshot in a WhatsApp group.
      expect(find.textContaining('hunter2'), findsNothing);
      expect(find.textContaining('postgres'), findsNothing);
      // The typing is still there, so the retry is one press.
      expect(find.text('Gauteng North'), findsOneWidget);
    });
  });

  group('every button is operable by a screen reader', () {
    testWidgets('blocked and armed alike', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expectEveryButtonActivatable(tester);

      await _fill(tester);
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, per phase × skin', () {
    for (final skin in torchSkins) {
      // WAS `· blocked`, EXPECTING 0, AND THE 0 WAS THE GHOST'S SIGNATURE.
      //
      // The old comment read "a disabled primary is not a lit one: nothing is
      // armed yet", which was a true reading of a screen that arrived with a
      // dead button. The button is live from the first frame now, so an
      // untouched form spends **one** object in both skins — measured at
      // `320x56` at `20,644`, which is the commit block itself.
      //
      // This is the grant #515 spent on `/forgot-password` and
      // `/account/password`, spent again here: Night allows two and uses one,
      // **Day allows one and this is now it.** Anything this screen later
      // wants lit has to take it from this button.
      testWidgets('${skin.mode.name} · untouched spends exactly one', (
        tester,
      ) async {
        await _pump(tester, skin: skin);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'territory form',
          phase: 'untouched',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('${skin.mode.name} · armed spends exactly one', (
        tester,
      ) async {
        await _pump(tester, skin: skin);
        await _fill(tester);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'territory form',
          phase: 'armed',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0× on a 320dp phone', (tester) async {
      await _pump(tester, textScale: 2.0, size: const Size(320, 900));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans labels and the Afrikaans blocked reason', (
      tester,
    ) async {
      await _pump(
        tester,
        locale: const Locale('af'),
        textScale: 2.0,
        size: const Size(320, 900),
      );

      expect(find.text('Nuwe gebied'), findsWidgets);
      expect(find.text('Skep gebied'), findsOneWidget);
      expect(find.text('Create territory'), findsNothing);

      // The Afrikaans reason is still asserted, and still at 2.0× on a 320dp
      // phone — it is simply earned by a press now, like the English one.
      // That is the point of keeping this assertion rather than dropping it:
      // the longest blocked reason in either language is the one most likely
      // to overflow the bar note, so it has to be on screen to be measured.
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-save-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('’n Naam en ’n kode is albei verpligtend.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
