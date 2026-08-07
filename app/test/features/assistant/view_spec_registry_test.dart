import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
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
      // the app separately.
      await tester.pumpWidget(wrap(ArtifactView(artifact: artifact('trend_chart'))));

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
}
