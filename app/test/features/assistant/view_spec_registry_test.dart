import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/charts.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/view_specs/view_spec_registry.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

ChatArtifact artifact(String type, {Object? data}) => ChatArtifact(
      id: 'a1',
      type: type,
      params: const {'agentId': 'agent-1'},
      data: data ?? const {},
    );

void main() {
  group('ArtifactView', () {
    testWidgets('renders a registered spec', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('agent_scorecard', data: const {
          'agentName': 'tumo@example.com',
          'averageScore': 82.0,
          'teamAverageScore': 71.0,
          'deltaVsTeam': 11.0,
          'visits': 14,
          'outletsVisited': 9,
          'scoredVisits': 12,
        }),
      )));

      expect(find.text('82.0'), findsOneWidget);
      expect(find.text('Team average 71.0'), findsOneWidget);
      expect(find.text('tumo@example.com'), findsOneWidget);
    });

    testWidgets('falls back to a note for an unknown spec type', (tester) async {
      // Never a blank card. A blank card reads as a bug in the app — the user
      // retries, sees the same nothing, and stops trusting the screen.
      await tester.pumpWidget(wrap(ArtifactView(artifact: artifact('pie_of_doom'))));

      expect(find.byType(UnsupportedArtifactNote), findsOneWidget);
      expect(find.textContaining('cannot draw yet'), findsOneWidget);
    });

    testWidgets('survives a spec type the server added after this build',
        (tester) async {
      // Not an error state — a normal consequence of shipping the backend and
      // the app separately. The fixture was `trend_chart` until this build
      // learned to draw it; `leaderboard` is the plan's next catalog entry
      // (Phase 1), so it plays the newer-server role now.
      await tester.pumpWidget(wrap(ArtifactView(artifact: artifact('leaderboard'))));

      expect(tester.takeException(), isNull);
      expect(find.byType(UnsupportedArtifactNote), findsOneWidget);
    });

    testWidgets('renders when the tool result is missing fields', (tester) async {
      // The spec params are server-validated; the shape of the tool RESULT is
      // not part of that contract. A missing field must not throw.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('agent_scorecard', data: const {}),
      )));

      expect(tester.takeException(), isNull);
      // Omission, not zero: "0 visits" and "visits were never captured" call
      // for opposite responses from a manager.
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('renders when the tool result is not a map at all', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('agent_scorecard', data: 'unexpected'),
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when there is no team to compare against',
        (tester) async {
      // "Team average —" would read as a missing number rather than an absent
      // team, and those mean different things.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('agent_scorecard', data: const {
          'averageScore': 64.0,
          'teamAverageScore': null,
        }),
      )));

      expect(find.textContaining('No other agent'), findsOneWidget);
    });
  });

  group('TrendChartCard', () {
    testWidgets('renders a titled line chart from the tool result', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('trend_chart', data: const {
          'metric': 'availability',
          'interval': 'day',
          'points': [
            {'period': '2026-08-01T00:00:00.000Z', 'value': 62.0, 'count': 4},
            {'period': '2026-08-02T00:00:00.000Z', 'value': 71.0, 'count': 6},
          ],
        }),
      )));

      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('On-shelf availability'), findsOneWidget);
      expect(find.text('By day'), findsOneWidget);
    });

    testWidgets('skips unreadable rows instead of plotting them as zero',
        (tester) async {
      // A fabricated zero IS a data point on a chart — it changes what the
      // line says. One readable point remains, which is below the chart's own
      // two-point minimum, so its honest empty state shows.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('trend_chart', data: const {
          'metric': 'execution_score',
          'points': [
            {'period': '2026-08-01', 'value': 'not a number'},
            'not even a map',
            {'period': '2026-08-02', 'value': 74.0},
          ],
        }),
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('Not enough data to plot'), findsOneWidget);
    });

    testWidgets('renders when the tool result is missing everything', (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('trend_chart', data: const {}),
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('Trend'), findsOneWidget);
      expect(find.text('Not enough data to plot'), findsOneWidget);
    });
  });

  group('OutletMapCard', () {
    testWidgets('draws a pin per outlet with the count in its semantics',
        (tester) async {
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('outlet_map', data: const {
          'worstOutlets': [
            {
              'outletId': 'o1',
              'outletName': 'Kasi Spaza',
              'outOfStockLines': 3,
              'lat': -26.2,
              'lng': 28.04,
            },
            {
              'outletId': 'o2',
              'outletName': 'Corner Shop',
              'outOfStockLines': 1,
              'lat': -26.1,
              'lng': 28.1,
            },
          ],
        }),
      )));

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o2')), findsOneWidget);
      expect(find.bySemanticsLabel('Kasi Spaza, 3 lines out of stock'), findsOneWidget);
      expect(find.text('2 outlets'), findsOneWidget);
    });

    testWidgets('skips rows without a finite coordinate rather than guessing',
        (tester) async {
      // A pin at (0, 0) is an answer about the Gulf of Guinea, not about
      // stock. The one readable outlet still gets its map.
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('outlet_map', data: const {
          'worstOutlets': [
            {'outletId': 'o1', 'outletName': 'No coords'},
            {
              'outletId': 'o2',
              'outletName': 'Kasi Spaza',
              'outOfStockLines': 2,
              'lat': -26.2,
              'lng': 28.04,
            },
          ],
        }),
      )));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o2')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stockout-pin-icon-o1')), findsNothing);
      expect(find.text('1 outlet'), findsOneWidget);
    });

    testWidgets('says so when no outlet location can be read', (tester) async {
      // The tool only declares this spec when it has outlets to point at, so
      // an unreadable list means the result shape moved under this build. An
      // empty world map would read as "no problem anywhere".
      await tester.pumpWidget(wrap(ArtifactView(
        artifact: artifact('outlet_map', data: const {'worstOutlets': 'unexpected'}),
      )));

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.textContaining('could not be read'), findsOneWidget);
    });
  });
}
