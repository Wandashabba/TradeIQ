import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/worklist.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

/// A realistic offline failure: the DioException whose toString is the
/// multi-line dump — SocketException, hostname and all — that used to reach
/// every console screen through AsyncSection's `$err` interpolation.
DioException _offline() => DioException(
      requestOptions: RequestOptions(path: '/alerts'),
      type: DioExceptionType.connectionError,
      error: 'SocketException: Failed host lookup: api.tradeiq.internal',
    );

void main() {
  group('AsyncSection', () {
    testWidgets('an error renders human copy, never the raw exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AsyncSection<List<int>>(
            value: AsyncValue.error(_offline(), StackTrace.current),
            label: 'alerts',
            onRetry: () {},
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      // The prefix the ~20 screen tests key on, followed by the shared
      // helper's copy — one sentence an agent can act on.
      expect(
        find.text(
          'Failed to load alerts. Could not reach the server. '
          'Check your connection and try again.',
        ),
        findsOneWidget,
      );
      // And none of the dump. Offline is the expected state in this app, not
      // an incident to report in stack-trace form.
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('api.tradeiq.internal'), findsNothing);
    });

    testWidgets('the error state always offers a retry', (tester) async {
      // A dead-end error state is a bug: the whole point of naming the
      // failure is to offer the way back.
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          AsyncSection<List<int>>(
            value: AsyncValue.error(_offline(), StackTrace.current),
            label: 'alerts',
            onRetry: () => retried = true,
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      expect(retried, isTrue);
    });

    testWidgets('data still flows through to the builder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AsyncSection<String>(
            value: const AsyncValue.data('loaded'),
            label: 'alerts',
            onRetry: () {},
            builder: (data) => Text(data),
          ),
        ),
      );

      expect(find.text('loaded'), findsOneWidget);
      expect(find.textContaining('Failed to load'), findsNothing);
    });
  });
}
