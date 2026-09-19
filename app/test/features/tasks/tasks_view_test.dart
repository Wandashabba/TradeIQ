import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_view.dart';

/// Wednesday 2026-07-22, midday — every SLA below is phrased against it.
final DateTime _now = DateTime(2026, 7, 22, 12);

TaskItem _task({
  String id = 't1',
  String findingType = 'out_of_stock',
  String fix = 'Restock SKU 42',
  String priority = 'normal',
  String status = 'open',
  bool verified = false,
  DateTime? due,
}) => TaskItem(
  id: id,
  findingType: findingType,
  requiredFix: fix,
  priority: priority,
  status: status,
  closureVerified: verified,
  outletId: 'o1',
  visitId: 'v1',
  slaDueAt: due ?? _now.add(const Duration(days: 3)),
);

TaskRow _row(TaskItem task) => TasksView.resolve(<TaskEntry>[
  TaskEntry(task: task, outletName: 'Kasi Corner Spaza'),
], _now).rows.single;

void main() {
  group('the SLA is a phrase, not a pill', () {
    test('overdue is floored to whole days, never fake-precise hours', () {
      final row = _row(
        _task(due: _now.subtract(const Duration(days: 2, hours: 3))),
      );
      expect(row.slaState, TaskSlaState.overdue);
      expect(row.slaPhrase, 'Overdue by 2 days');
    });

    test('under a day late says so in words rather than in hours', () {
      final row = _row(_task(due: _now.subtract(const Duration(hours: 3))));
      expect(row.slaPhrase, 'Overdue by less than a day');
    });

    test('one day late is singular', () {
      final row = _row(_task(due: _now.subtract(const Duration(days: 1))));
      expect(row.slaPhrase, 'Overdue by 1 day');
    });

    test('inside 24 hours the unit becomes hours, which is what is counted', () {
      final row = _row(_task(due: _now.add(const Duration(hours: 6))));
      expect(row.slaState, TaskSlaState.dueSoon);
      expect(row.slaPhrase, 'Due in 6 h');
    });

    test('further out it is a calendar distance', () {
      final row = _row(_task(due: _now.add(const Duration(days: 3))));
      expect(row.slaState, TaskSlaState.open);
      expect(row.slaPhrase, 'Due Saturday');
    });

    test('past a week it is a date', () {
      final row = _row(_task(due: _now.add(const Duration(days: 21))));
      expect(row.slaPhrase, 'Due 12 Aug');
    });

    test('closed and verified are states, not deadlines', () {
      expect(
        _row(_task(status: 'closed', due: _now.subtract(const Duration(days: 9)))).slaPhrase,
        'Closed',
      );
      expect(
        _row(_task(status: 'closed', verified: true)).slaPhrase,
        'Verified',
      );
    });

    test(
      'a 23-hour local day does not turn tomorrow into today',
      () {
        // The calendar distance is computed at UTC midnight on both ends, so a
        // spring-forward cannot floor a 23-hour day to zero and label a
        // tomorrow-due task "Due today".
        final now = DateTime(2026, 9, 5, 23, 30);
        final due = DateTime(2026, 9, 6, 22);
        expect(
          TasksView.slaPhrase(due, TaskSlaState.open, now),
          'Due tomorrow',
        );
      },
    );
  });

  group('the bar is the SLA, raised by the priority', () {
    test('overdue is solid, whatever the priority says', () {
      final row = _row(
        _task(priority: 'normal', due: _now.subtract(const Duration(days: 1))),
      );
      expect(row.severity, SoftRowSeverity.critical);
      expect(row.severityLabel, 'Overdue');
    });

    test('a critical finding is solid before it is late', () {
      final row = _row(_task(priority: 'critical'));
      expect(row.severity, SoftRowSeverity.critical);
      expect(row.severityLabel, 'Critical');
    });

    test('open work is never bar-less: a bar-less row means fine', () {
      final row = _row(_task(priority: 'normal'));
      expect(row.severity, SoftRowSeverity.watch);
      expect(row.severityLabel, 'Normal');
    });

    test('a closed row carries no bar at all', () {
      final row = _row(_task(status: 'closed'));
      expect(row.severity, SoftRowSeverity.none);
    });
  });

  group('sorting and filtering', () {
    final tasks = <TaskItem>[
      _task(id: 'normal'),
      _task(id: 'critical', priority: 'critical'),
      _task(id: 'closed', status: 'closed'),
      _task(id: 'late', due: _now.subtract(const Duration(days: 1))),
      _task(id: 'high', priority: 'high'),
    ];
    final view = TasksView.resolve(<TaskEntry>[
      for (final t in tasks) TaskEntry(task: t, outletName: 'Outlet'),
    ], _now);

    test('overdue, critical, high, normal, closed', () {
      expect(view.rows.map((r) => r.id).toList(), <String>[
        'late',
        'critical',
        'high',
        'normal',
        'closed',
      ]);
    });

    test('Open includes overdue — overdue is a focus, not a state', () {
      final open = view.visible(TaskFilter.open).map((r) => r.id).toList();
      expect(open, contains('late'));
      expect(open, isNot(contains('closed')));
    });

    test('Overdue narrows to open work past its deadline', () {
      expect(
        view.visible(TaskFilter.overdue).map((r) => r.id).toList(),
        <String>['late'],
      );
    });

    test('Done is closed work; All is everything', () {
      expect(view.visible(TaskFilter.done).length, 1);
      expect(view.visible(TaskFilter.all).length, 5);
    });

    test('the counts are of the loaded page and nothing else', () {
      expect(view.overdue, 1);
      expect(view.open, 4);
      expect(view.closed, 1);
      expect(view.awaitingVerification, 1);
    });
  });

  group('the finding becomes words', () {
    test('a slug is machine-facing and this is the row s first line', () {
      expect(TasksView.findingLabel('out_of_stock'), 'Out of stock');
      expect(TasksView.findingLabel('price_deviation'), 'Price deviation');
    });

    test('an unknown finding reads as itself — nothing is invented', () {
      expect(TasksView.findingLabel('gondola_end_empty'), 'Gondola end empty');
      expect(TasksView.findingLabel(''), '');
    });
  });

  test('a row names the outlet it was given, never a UUID of its own', () {
    final view = TasksView.resolve(<TaskEntry>[
      TaskEntry(task: _task(), outletName: 'Kasi Corner Spaza'),
    ], _now);
    expect(view.rows.single.outletName, 'Kasi Corner Spaza');
  });

  group('the footer owns up to a cut list', () {
    String figure(int n) => '$n';
    final entries = <TaskEntry>[
      TaskEntry(task: _task(), outletName: 'Kasi Corner Spaza'),
      TaskEntry(task: _task(id: 't2'), outletName: 'Kasi Corner Spaza'),
    ];

    test('a page that is the whole list has no footer', () {
      expect(TasksView.resolve(entries, _now).footer(figure), isNull);
    });

    test('an uncounted cut says there are more, and no number', () {
      final footer = TasksView.resolve(
        entries,
        _now,
        nextCursor: 'c',
      ).footer(figure)!;
      expect(footer.summary, 'Showing the first 2. There are more.');
      expect(footer.scope, 'The counts above are of these 2.');
    });

    test('a counted cut names the total and the order it was cut in', () {
      final footer = TasksView.resolve(
        entries,
        _now,
        nextCursor: 'c',
        total: 74,
      ).footer(figure)!;
      expect(
        footer.summary,
        'Showing the 2 tasks with the earliest deadlines, of 74.',
      );
    });

    test('a total no larger than the page is not repeated as "of"', () {
      final footer = TasksView.resolve(
        entries,
        _now,
        nextCursor: 'c',
        total: 2,
      ).footer(figure)!;
      expect(footer.summary, 'Showing the first 2. There are more.');
    });
  });

  group('the owner', () {
    test('is named from the roster, and absent where the roster is silent', () {
      final view = TasksView.resolve(
        <TaskEntry>[
          TaskEntry(
            task: TaskItem(
              id: 'named',
              findingType: 'out_of_stock',
              requiredFix: 'Restock',
              priority: 'normal',
              status: 'open',
              closureVerified: false,
              outletId: 'o1',
              slaDueAt: _now.add(const Duration(days: 3)),
              ownerId: 'u-1',
            ),
            outletName: 'Kasi Corner Spaza',
          ),
          TaskEntry(
            task: TaskItem(
              id: 'unnamed',
              findingType: 'out_of_stock',
              requiredFix: 'Restock',
              priority: 'normal',
              status: 'open',
              closureVerified: false,
              outletId: 'o1',
              slaDueAt: _now.add(const Duration(days: 3)),
              ownerId: 'u-9',
            ),
            outletName: 'Kasi Corner Spaza',
          ),
        ],
        _now,
        owners: const <String, String>{'u-1': 'Thandi Mokoena'},
      );
      final byId = {for (final r in view.rows) r.id: r};
      expect(byId['named']!.owner, 'Thandi Mokoena');
      expect(byId['unnamed']!.owner, isNull);
    });

    test('ownerId is read off the wire', () {
      final item = TaskItem.fromJson(<String, dynamic>{
        'id': 't',
        'findingType': 'out_of_stock',
        'requiredFix': 'Restock',
        'priority': 'normal',
        'status': 'open',
        'outletId': 'o1',
        'slaDueAt': '2026-07-25T00:00:00.000Z',
        'ownerId': 'u-1',
      });
      expect(item.ownerId, 'u-1');
    });
  });
}
