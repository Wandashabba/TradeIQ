import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../helpers/routed_app.dart';

const _khumalo = Outlet(
  id: 'o1',
  name: 'Khumalo Superette',
  code: 'KS-014',
  lat: -26.2,
  lng: 28.0,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-221',
  lat: -26.3,
  lng: 28.1,
);

Widget _app(TodayRoute? route) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);

  return routedApp(
    const TodayScreen(),
    overrides: [
      localDbProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.empty)),
      todayRouteProvider.overrideWith((ref) async => route),
    ],
  );
}

TodayRoute _route({bool located = true}) => TodayRoute(
      planName: 'Naledi · Soweto East',
      hasLocation: located,
      stops: [
        RouteStop(
          sequence: 1,
          outlet: _khumalo,
          visited: true,
          distanceMeters: located ? 1200 : null,
        ),
        RouteStop(
          sequence: 2,
          outlet: _sunrise,
          visited: false,
          distanceMeters: located ? 42 : null,
        ),
      ],
    );

void main() {
  testWidgets('the day is the first thing an agent sees', (tester) async {
    await tester.pumpWidget(_app(_route()));
    await tester.pumpAndSettle();

    // Not "which of 400 outlets would you like to audit" — where am I going, and
    // how much is left.
    expect(find.text('Khumalo Superette'), findsOneWidget);
    expect(find.text('Sunrise Spaza'), findsOneWidget);
    expect(find.textContaining('of 2 stores'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);
  });

  testWidgets('the next store is marked, and the visited one recedes', (tester) async {
    await tester.pumpWidget(_app(_route()));
    await tester.pumpAndSettle();

    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('distance is a walk or a drive, not a number of metres', (tester) async {
    await tester.pumpWidget(_app(_route()));
    await tester.pumpAndSettle();

    expect(find.text('42 m away'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
  });

  testWidgets('no location means no distances — not made-up ones', (tester) async {
    await tester.pumpWidget(_app(_route(located: false)));
    await tester.pumpAndSettle();

    expect(find.textContaining('m away'), findsNothing);
    expect(find.textContaining('will not say where it is'), findsOneWidget);
  });

  testWidgets('no plan is an answer, not a dead end', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();

    // A manager who has not built a beat plan has not built one. The screen says
    // so, rather than inventing a route out of the outlet list — and it still
    // lets the agent work.
    expect(find.text('No route planned for today'), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-a-store')), findsOneWidget);
  });

  testWidgets('the plan is not a cage — an unplanned store is one tap away', (tester) async {
    await tester.pumpWidget(_app(_route()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('visit-another')), findsOneWidget);
  });
}
