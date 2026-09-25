import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/create_outlet_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../core/design/amber_golden.dart';
import '../operations_harness.dart';

const List<Territory> _territories = <Territory>[
  // The name a manager knows, and the code the column actually stores.
  Territory(id: 't1', name: 'Hurlingham', code: '2773u'),
  Territory(id: 't2', name: 'Gauteng North', code: 'gauteng-north'),
];

Future<FakeOpsOutletsRepository> _pump(
  WidgetTester tester, {
  List<Territory> territories = _territories,
  Object? territoriesFailure,
  Object? createFailure,
  LocationPermission permission = LocationPermission.whileInUse,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
}) async {
  final outlets = FakeOpsOutletsRepository(createFailure: createFailure);
  await pumpOperations(
    tester,
    const CreateOutletScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    overrides: <Override>[
      outletsRepositoryProvider.overrideWithValue(outlets),
      territoriesRepositoryProvider.overrideWithValue(
        FakeTerritoriesRepository(
          territories: territories,
          failure: territoriesFailure,
        ),
      ),
      locationServiceProvider.overrideWithValue(
        fakeLocationService(permission: permission),
      ),
    ],
  );
  return outlets;
}

/// Fill in everything the server needs except the territory.
Future<void> _fillStore(WidgetTester tester) async {
  await scrollOpsTo(
    tester,
    find.byKey(const ValueKey<String>('create-outlet-name')),
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('create-outlet-name')),
    'Hurlingham Market',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('create-outlet-code')),
    'HM-001',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('create-outlet-channel')),
    'supermarket',
  );
  await tester.pumpAndSettle();
}

TorchPrimaryButton _submit(WidgetTester tester) =>
    tester.widget<TorchPrimaryButton>(
      find.byKey(const ValueKey<String>('create-outlet-submit')),
    );

void main() {
  group('the territory', () {
    testWidgets('is chosen from a list, not typed', (tester) async {
      await _pump(tester);
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('territory-picker')),
      );
      expect(
        find.byKey(const ValueKey<String>('territory-picker')),
        findsOneWidget,
      );
      // The old free-text field is gone — it is what let a name be filed as a
      // code — and so is the Material dropdown that replaced it.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('submits the CODE, not the name shown', (tester) async {
      final outlets = await _pump(tester);
      await _fillStore(tester);
      await pickOption(
        tester,
        const ValueKey<String>('territory-picker'),
        'Hurlingham',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('create-outlet-submit')),
      );
      await tester.pumpAndSettle();

      // The regression this exists for: a real outlet was filed under
      // 'Hurlingham' — the territory's name — while the column wanted
      // '2773u', so it matched no territory and vanished from every scoped
      // view.
      expect(outlets.createdTerritoryId, '2773u');
      expect(outlets.createdName, 'Hurlingham Market');
    });

    testWidgets('nothing chosen keeps the commit disarmed, and says why', (
      tester,
    ) async {
      final outlets = await _pump(tester);
      await _fillStore(tester);

      final button = _submit(tester);
      expect(button.onPressed, isNull);
      expect(button.blockedReason, isNotNull);
      expect(outlets.createCount, 0);
    });

    testWidgets('says what to do when no territory exists yet', (tester) async {
      await _pump(tester, territories: const <Territory>[]);
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('territory-picker')),
      );
      // An empty picker reads as broken; this names the missing prerequisite.
      await tester.tap(find.byKey(const ValueKey<String>('territory-picker')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No territories yet'), findsOneWidget);
    });

    testWidgets('the sheet tells a reader which territory is already set', (
      tester,
    ) async {
      // The kit test pins the word; this one pins that the word reaches a real
      // screen through the real delegates, in the language the screen is in.
      // A manager reopening the picker to change a value could otherwise only
      // see which one was set — a tick, and nothing spoken.
      final handle = tester.ensureSemantics();
      await _pump(tester, locale: const Locale('af'));
      await pickOption(
        tester,
        const ValueKey<String>('territory-picker'),
        'Hurlingham',
      );
      await tester.tap(find.byKey(const ValueKey<String>('territory-picker')));
      await tester.pumpAndSettle();

      final labels = semanticsNodes(
        tester,
      ).map((n) => n.getSemanticsData().label).toList();
      expect(
        labels.where((l) => l.contains('Gekies') && l.contains('Hurlingham')),
        isNotEmpty,
        reason: semanticsDump(tester),
      );
      expect(
        labels.where((l) => l.contains('Gekies') && l.contains('Gauteng')),
        isEmpty,
      );
      handle.dispose();
    });

    testWidgets('a territory list that failed offers a retry', (tester) async {
      await _pump(
        tester,
        territoriesFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('territories-retry')),
      );
      expect(find.text('The territory list did not load.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('the pin (#386)', () {
    testWidgets('the coordinate fields are editable, and seeded', (
      tester,
    ) async {
      await _pump(tester);

      // Editable is the whole point: a manager onboarding forty stores from
      // the depot must be able to type where each shop actually is.
      final lat = tester.widget<TorchTextField>(
        find.byKey(const ValueKey<String>('create-outlet-lat')),
      );
      expect(lat.readOnly, isFalse);
      expect(lat.controller!.text, '-26.089');
      expect(
        find.text(
          'Seeded from this phone. Type over it if you are not standing in '
          'the store.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('typed coordinates are what reaches the wire', (tester) async {
      final outlets = await _pump(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('create-outlet-lat')),
        '-26.2678',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('create-outlet-lng')),
        '27.8586',
      );
      await _fillStore(tester);
      await pickOption(
        tester,
        const ValueKey<String>('territory-picker'),
        'Hurlingham',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('create-outlet-submit')),
      );
      await tester.pumpAndSettle();

      expect(outlets.createdLat, -26.2678);
      expect(outlets.createdLng, 27.8586);
    });

    testWidgets('a refused fix still lets a store be created', (tester) async {
      final outlets = await _pump(
        tester,
        permission: LocationPermission.denied,
      );

      expect(
        find.textContaining('This phone will not say where it is'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('create-outlet-lat')),
        '-26.2678',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('create-outlet-lng')),
        '27.8586',
      );
      await _fillStore(tester);
      await pickOption(
        tester,
        const ValueKey<String>('territory-picker'),
        'Hurlingham',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('create-outlet-submit')),
      );
      await tester.pumpAndSettle();

      expect(outlets.createCount, 1);
      expect(outlets.createdLat, -26.2678);
    });

    testWidgets('an off-globe latitude keeps the commit disarmed', (
      tester,
    ) async {
      final outlets = await _pump(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('create-outlet-lat')),
        'x',
      );
      await _fillStore(tester);
      await pickOption(
        tester,
        const ValueKey<String>('territory-picker'),
        'Hurlingham',
      );
      expect(_submit(tester).onPressed, isNull);
      expect(outlets.createCount, 0);
    });
  });

  group('failure', () {
    testWidgets('says nothing was saved, and does not print the exception', (
      tester,
    ) async {
      await _pump(
        tester,
        createFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      await _fillStore(tester);
      await pickOption(
        tester,
        const ValueKey<String>('territory-picker'),
        'Hurlingham',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('create-outlet-submit')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('That store was not created. Nothing was saved.'),
        findsOneWidget,
      );
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      await settleOpsToasts(tester);
    });
  });

  group('the notation the screen itself asks for', () {
    // THE FAILURE, WRITTEN DOWN: the help line under the field said
    // "Johannesburg is omtrent -26,2", the refusal said "Tik ’n getal in,
    // byvoorbeeld -26,2041", and `double.tryParse` knew neither. A manager on
    // an Afrikaans handset — whose decimal key IS a comma — typed exactly what
    // she was told to and "Voeg die winkel by" stayed dark, with the refusal
    // repeating her own comma back at her. The pre-migration field carried an
    // input filter that made the comma untypeable; the filter went with the
    // field and nothing replaced it.
    testWidgets('a comma decimal arms the commit in Afrikaans', (tester) async {
      final outlets = await _pump(tester, locale: const Locale('af'));

      await tester.enterText(
        find.byKey(const ValueKey<String>('create-outlet-lat')),
        '-26,20410',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('create-outlet-lng')),
        '28,04730',
      );
      await _fillStore(tester);
      await pickOption(
        tester,
        const ValueKey<String>('territory-picker'),
        'Hurlingham',
      );

      expect(_submit(tester).blockedReason, isNull);
      expect(_submit(tester).onPressed, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('create-outlet-submit')),
      );
      await tester.pumpAndSettle();

      expect(outlets.createdLat, closeTo(-26.2041, 1e-9));
      expect(outlets.createdLng, closeTo(28.0473, 1e-9));
    });

    testWidgets('a full stop still works on an Afrikaans handset', (
      tester,
    ) async {
      // The seeded value is written by the phone as `-26.089`, so the parser
      // that accepts the comma must not stop accepting the dot — or a manager
      // who touches nothing cannot save.
      final outlets = await _pump(tester, locale: const Locale('af'));
      await _fillStore(tester);
      await pickOption(
        tester,
        const ValueKey<String>('territory-picker'),
        'Hurlingham',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('create-outlet-submit')),
      );
      await tester.pumpAndSettle();

      expect(outlets.createdLat, closeTo(-26.089, 1e-9));
    });

    testWidgets('the printed example is a number this screen accepts', (
      tester,
    ) async {
      // Not the example *we* remember — the one the build actually prints. The
      // help line, the refusal and the parser agree or this fails.
      for (final locale in <Locale>[const Locale('en'), const Locale('af')]) {
        final outlets = await _pump(tester, locale: locale);
        final l10n = await AppLocalizations.delegate.load(locale);

        // "Enter a number, for example -26.2041" → "-26.2041".
        final example = RegExp(
          r'[-−]?\d+[.,]\d+',
        ).firstMatch(l10n.outletCoordinateNotANumber)!.group(0)!;

        await tester.enterText(
          find.byKey(const ValueKey<String>('create-outlet-lat')),
          example,
        );
        await _fillStore(tester);
        await pickOption(
          tester,
          const ValueKey<String>('territory-picker'),
          'Hurlingham',
        );

        expect(
          _submit(tester).onPressed,
          isNotNull,
          reason:
              'the refusal prints "$example" as the shape of a coordinate, '
              'and then $locale refuses it',
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('create-outlet-submit')),
        );
        await tester.pumpAndSettle();

        expect(outlets.createCount, 1);
        expect(outlets.createdLat, closeTo(-26.2041, 1e-9));
        expect(find.text(l10n.outletCoordinateNotANumber), findsNothing);
      }
    });
  });

  group('Afrikaans and 2.0x', () {
    testWidgets('Afrikaans has no English left on it', (tester) async {
      await _pump(tester, locale: const Locale('af'));
      expect(find.text('Voeg ’n winkel by'), findsWidgets);
      expect(find.text('Waar hierdie winkel is'.toUpperCase()), findsOneWidget);
      expect(find.text('Breedtegraad'), findsOneWidget);
      expect(find.text('Latitude'), findsNothing);
    });

    testWidgets('2.0x does not overflow', (tester) async {
      await _pump(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans at 1.4x does not overflow either', (tester) async {
      await _pump(tester, textScale: 1.4, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
    });
  });

  group('every button is operable by a screen reader', () {
    // The kit shipped a component family that announced itself and did
    // nothing when a screen reader activated it, and `SectionRuleAction` and
    // `PaginationFooter.action` were still shipping that way when this group
    // was migrated. This is the guard, on this screen, per phase — so no
    // local `Semantics(button: true, excludeSemantics: true)` around a bare
    // GestureDetector can bring it back.
    testWidgets('the empty form', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });

    testWidgets('with the territories refused', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, territoriesFailure: StateError('no route to host'));
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, every phase in every skin', () {
    /// Not a tab root: the thumb zone carries the one commit and nothing else
    /// on this form is a light. It is armed only when every required value is
    /// present, so an empty form paints nothing at all.
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets('${skin.mode.name}, form (nothing armed): 0', (tester) async {
        await _pump(tester, skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'create-outlet',
          phase: 'form',
        );
        expect(
          census.objectCount,
          0,
          reason:
              'A commit that would be refused is not the expected next move, '
              'so nothing is lit.\n${census.describe()}',
        );
      });

      testWidgets('${skin.mode.name}, form (complete): 1', (tester) async {
        await _pump(tester, skin: skin);
        await _fillStore(tester);
        await pickOption(
          tester,
          const ValueKey<String>('territory-picker'),
          'Hurlingham',
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'create-outlet',
          phase: 'form-complete',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'One object: the primary commit block. The nav is not on this '
              'route at all.\n${census.describe()}',
        );
      });
    }
  });
}
