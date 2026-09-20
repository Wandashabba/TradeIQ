import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/format/person_label.dart';

void main() {
  group('personLabel', () {
    test('uses the display name when there is one', () {
      expect(personLabel('Sipho Ndlovu', 'agent@example.com'), 'Sipho Ndlovu');
    });

    test('trims the display name', () {
      expect(personLabel('  Sipho Ndlovu ', 'agent@example.com'), 'Sipho Ndlovu');
    });

    test('falls back to the email when the name is null', () {
      expect(personLabel(null, 'agent@example.com'), 'agent@example.com');
    });

    test('falls back to the email when the name is empty or whitespace', () {
      expect(personLabel('', 'agent@example.com'), 'agent@example.com');
      expect(personLabel('   ', 'agent@example.com'), 'agent@example.com');
    });
  });

  group('nonBlankName', () {
    test('returns the trimmed name', () {
      expect(nonBlankName(' Lerato '), 'Lerato');
    });

    test('returns null for null, empty and whitespace', () {
      expect(nonBlankName(null), isNull);
      expect(nonBlankName(''), isNull);
      expect(nonBlankName('  '), isNull);
    });
  });
}
