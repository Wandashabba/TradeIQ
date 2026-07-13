import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';

void main() {
  test('dark theme uses the shared AppColors background', () {
    final theme = AppTheme.dark();
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });
}
