import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';

void main() {
  test('dark theme uses the deck navy background', () {
    final theme = AppTheme.dark();
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0B1220));
  });
}
