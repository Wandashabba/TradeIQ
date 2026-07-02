import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/router/app_router.dart';

void main() {
  testWidgets('unauthenticated root route shows the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    expect(find.text('TradeIQ Login'), findsOneWidget);
  });
}
