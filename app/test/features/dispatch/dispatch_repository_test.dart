import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/dispatch/data/dispatch_repository.dart';

void main() {
  group('DispatchResult.fromJson', () {
    test('parses candidates and a recommended candidate', () {
      final result = DispatchResult.fromJson(const {
        'outletId': 'o1',
        'recommended': {
          'agentId': 'a1',
          'email': 'near@example.com',
          'distanceM': 120.4,
          'inTerritory': true,
        },
        'candidates': [
          {
            'agentId': 'a1',
            'email': 'near@example.com',
            'distanceM': 120.4,
            'inTerritory': true,
          },
          {
            'agentId': 'a2',
            'email': 'far@example.com',
            'distanceM': null,
            'inTerritory': false,
          },
        ],
      });

      expect(result.candidates, hasLength(2));
      expect(result.recommended, isNotNull);
      expect(result.recommended!.email, 'near@example.com');
      expect(result.recommended!.distanceM, 120.4);
      expect(result.recommended!.inTerritory, isTrue);

      final far = result.candidates[1];
      expect(far.agentId, 'a2');
      expect(far.email, 'far@example.com');
      expect(far.distanceM, isNull);
      expect(far.inTerritory, isFalse);
    });

    test('handles a null recommended', () {
      final result = DispatchResult.fromJson(const {
        'outletId': 'o1',
        'recommended': null,
        'candidates': [
          {
            'agentId': 'a2',
            'email': 'far@example.com',
            'distanceM': null,
            'inTerritory': false,
          },
        ],
      });

      expect(result.recommended, isNull);
      expect(result.candidates, hasLength(1));
      expect(result.candidates.first.distanceM, isNull);
    });
  });
}
