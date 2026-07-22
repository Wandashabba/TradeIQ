import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/agents/data/agents_repository.dart';

void main() {
  group('AgentActivity.fromJson', () {
    test('parses an agent with stops', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a1',
        'name': 'thabo@example.com',
        'state': 'at_store',
        'currentOutlet': {'id': 'o1', 'name': 'Sandton Spar'},
        'lastSeenAt': '2026-07-22T08:00:00.000Z',
        'stops': [
          {
            'visitId': 'v1',
            'outletId': 'o1',
            'outletName': 'Sandton Spar',
            'lat': -26.1,
            'lng': 28.05,
            'checkinTs': '2026-07-22T08:00:00.000Z',
            'status': 'in_progress',
          },
        ],
      });

      expect(activity.agentId, 'a1');
      expect(activity.state, AgentState.atStore);
      expect(activity.currentOutletName, 'Sandton Spar');
      expect(activity.stops, hasLength(1));
      expect(activity.stops.first.lat, -26.1);
      expect(activity.lastSeenAt, DateTime.utc(2026, 7, 22, 8));
    });

    test('parses an idle agent with no stops and no last-seen', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a2',
        'name': 'sipho@example.com',
        'state': 'idle',
        'currentOutlet': null,
        'lastSeenAt': null,
        'stops': <Map<String, dynamic>>[],
      });

      expect(activity.state, AgentState.idle);
      expect(activity.currentOutletName, isNull);
      expect(activity.lastSeenAt, isNull);
      expect(activity.stops, isEmpty);
    });

    // An unknown state must not crash the panel. Falling back to idle is the
    // honest default: it claims nothing.
    test('falls back to idle on an unrecognised state', () {
      final activity = AgentActivity.fromJson(const {
        'agentId': 'a3',
        'name': 'x@example.com',
        'state': 'teleporting',
        'currentOutlet': null,
        'lastSeenAt': null,
        'stops': <Map<String, dynamic>>[],
      });
      expect(activity.state, AgentState.idle);
    });
  });

  group('dayBoundsLocal', () {
    // The client owns the timezone decision — see the route comment on
    // GET /agents/activity. These must be local midnights, not UTC ones.
    test('returns local midnight to the next local midnight', () {
      final (from, to) = dayBoundsLocal(DateTime(2026, 7, 22, 14, 30));
      expect(from, DateTime(2026, 7, 22));
      expect(to, DateTime(2026, 7, 23));
    });

    test('spans exactly one day across a month boundary', () {
      final (from, to) = dayBoundsLocal(DateTime(2026, 7, 31, 9));
      expect(from, DateTime(2026, 7, 31));
      expect(to, DateTime(2026, 8, 1));
    });
  });
}
