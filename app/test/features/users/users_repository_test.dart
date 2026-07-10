import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

void main() {
  test('AppUser.fromJson parses all fields', () {
    final user = AppUser.fromJson(const {
      'id': 'u1',
      'email': 'agent@example.com',
      'role': 'field_agent',
      'active': false,
    });

    expect(user.id, 'u1');
    expect(user.email, 'agent@example.com');
    expect(user.role, 'field_agent');
    expect(user.active, isFalse);
  });

  test('AppUser.fromJson defaults active to true when missing', () {
    final user = AppUser.fromJson(const {
      'id': 'u2',
      'email': 'manager@example.com',
      'role': 'manager',
    });

    expect(user.active, isTrue);
  });
}
