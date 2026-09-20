import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/collaboration/data/collaboration_repository.dart';
import 'package:tradeiq_app/features/collaboration/presentation/messages_screen.dart';
import 'package:tradeiq_app/features/reports/data/report_schedules_repository.dart';
import 'package:tradeiq_app/features/reports/data/reports_repository.dart';
import 'package:tradeiq_app/features/reports/presentation/report_run_history_screen.dart';
import 'package:tradeiq_app/features/reports/presentation/report_schedules_screen.dart';
import 'package:tradeiq_app/features/reports/presentation/reports_screen.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';
import 'package:tradeiq_app/features/templates/presentation/template_form_screen.dart';
import 'package:tradeiq_app/features/templates/presentation/templates_screen.dart';
import 'package:tradeiq_app/features/webhooks/data/webhooks_repository.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';

import '../features/reports/reports_harness.dart';
import '../features/reports/schedules_fakes.dart';
import '../features/templates/templates_harness.dart';
import '../features/worklist_harness.dart';

// ── THE FAILURE, WRITTEN OUT ─────────────────────────────────────────────
//
// An Afrikaans manager taps a nav item that reads "Verslae", "Webhake",
// "Ouditsjablone" or "Boodskappe" — `nav_destinations.dart` has translated
// those four labels for a while — and lands on a screen that says "Reports ·
// Definitions run on demand against live data · Run · Delete · New report".
// Territories, Dispatch and Trends, reached from the same menu sheet, read
// Afrikaans. The console was half translated and the boundary was this
// feature.
//
// Each case below pumps a screen at `af` and asserts an Afrikaans word IS on
// it and the English word it replaces is NOT. The second half is what makes
// it a guard: a screen that renders both is a screen with one hardcoded
// string left in it.

const _af = Locale('af');

void main() {
  group('the reporting console renders in Afrikaans', () {
    testWidgets('Reports', (tester) async {
      await pumpReports(
        tester,
        const ReportsScreen(),
        locale: _af,
        overrides: <Override>[
          reportsRepositoryProvider.overrideWithValue(FakeReportsRepository()),
        ],
      );

      expect(find.text('Verslae'), findsWidgets);
      expect(find.text('Definisies loop op aanvraag teen lewendige data.'),
          findsOneWidget);
      expect(find.text('Nuwe verslag'), findsOneWidget);
      expect(find.text('Loop'), findsWidgets);

      expect(find.text('Reports'), findsNothing);
      expect(find.text('New report'), findsNothing);
      expect(find.text('Run'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('Report schedules', (tester) async {
      await pumpReports(
        tester,
        const ReportSchedulesScreen(),
        locale: _af,
        overrides: <Override>[
          reportSchedulesRepositoryProvider.overrideWithValue(
            FakeSchedulesRepository(),
          ),
          reportsRepositoryProvider.overrideWithValue(FakeReportsRepository()),
        ],
      );

      expect(find.text('Verslagskedules'), findsOneWidget);
      expect(find.text('Aktief'), findsWidgets);
      expect(find.text('Weekliks'), findsWidgets);
      expect(find.text('Loop nou'), findsWidgets);
      expect(find.text('Wys ontvangers'), findsWidgets);
      expect(find.text('Nooit geloop nie'), findsWidgets);

      expect(find.text('Report schedules'), findsNothing);
      expect(find.text('Weekly'), findsNothing);
      expect(find.text('Run now'), findsNothing);
      expect(find.text('Show recipients'), findsNothing);
      expect(find.text('Never run'), findsNothing);
    });

    testWidgets('Run history', (tester) async {
      await pumpPushedReports(
        tester,
        ReportRunHistoryScreen(schedule: activeSchedule),
        locale: _af,
        overrides: <Override>[
          reportSchedulesRepositoryProvider.overrideWithValue(
            FakeSchedulesRepository(runs: const <ReportRun>[]),
          ),
        ],
      );

      expect(find.text('Lopiegeskiedenis'), findsOneWidget);
      expect(find.text('Nog geen lopies nie.'), findsOneWidget);
      expect(find.text('Herlaai'), findsOneWidget);

      expect(find.text('Run history'), findsNothing);
      expect(find.text('No runs yet.'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
    });

    testWidgets('Audit templates', (tester) async {
      await pumpWorklist(
        tester,
        const TemplatesScreen(),
        locale: _af,
        overrides: <Override>[
          templatesRepositoryProvider.overrideWithValue(
            FakeTemplatesRepository(),
          ),
        ],
      );

      expect(find.text('Ouditsjablone'), findsWidgets);
      expect(find.text('In veldoudits gebruik'), findsOneWidget);
      expect(find.text('Gebruik in oudits'), findsWidgets);

      expect(find.text('Audit templates'), findsNothing);
      expect(find.text('Used in field audits'), findsNothing);
      expect(find.text('Use in audits'), findsNothing);
    });

    testWidgets('Template preview', (tester) async {
      await pumpWorklist(
        tester,
        const PushedHost(child: TemplateFormScreen(templateId: 'tpl-1')),
        locale: _af,
        overrides: <Override>[
          templatesRepositoryProvider.overrideWithValue(
            FakeTemplatesRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // The facts are joined into one line by the header.
      expect(
        find.textContaining('Voorskou — niks word gestoor nie'),
        findsOneWidget,
      );
      expect(find.text('Volgende afdeling'), findsOneWidget);
      expect(find.text('Ja'), findsOneWidget);
      expect(find.text('Nee'), findsOneWidget);
      expect(find.text('Nog nie beantwoord nie.'), findsWidgets);
      // The kit's own tile words default to English; this screen passes its
      // own, so the provisional marker is Afrikaans too.
      expect(find.text('Voorlopig'), findsOneWidget);

      expect(find.textContaining('Preview — nothing is saved'), findsNothing);
      expect(find.text('Next section'), findsNothing);
      expect(find.text('Yes'), findsNothing);
      expect(find.text('No'), findsNothing);
      expect(find.text('Not answered yet.'), findsNothing);
      expect(find.text('Provisional'), findsNothing);
    });

    testWidgets('Webhooks', (tester) async {
      await pumpWorklist(
        tester,
        const WebhooksScreen(),
        locale: _af,
        overrides: <Override>[
          webhooksRepositoryProvider.overrideWithValue(
            _EmptyWebhooksRepository(),
          ),
        ],
      );

      expect(find.text('Webhake'), findsWidgets);
      expect(find.text('Eindpunte'), findsOneWidget);
      expect(find.text('Voeg ’n eindpunt by'), findsWidgets);

      expect(find.text('Webhooks'), findsNothing);
      expect(find.text('Endpoints'), findsNothing);
      expect(find.text('Add an endpoint'), findsNothing);
    });

    testWidgets('Messages', (tester) async {
      await pumpWorklist(
        tester,
        const MessagesScreen(),
        locale: _af,
        overrides: <Override>[
          collaborationRepositoryProvider.overrideWithValue(
            _EmptyCollaborationRepository(),
          ),
        ],
      );

      expect(find.text('Boodskappe'), findsWidgets);
      expect(find.text('Aankondigings'), findsWidgets);
      expect(find.text('Stuur'), findsOneWidget);
      expect(find.text('Stuur die span ’n boodskap'), findsWidgets);

      expect(find.text('Messages'), findsNothing);
      expect(find.text('Announcements'), findsNothing);
      expect(find.text('Send'), findsNothing);
      expect(find.text('Message the team'), findsNothing);
    });
  });

  // A rendering test can only reach the phases it pumps. This one reads the
  // sources, so a string in a branch no test opens is still caught.
  test('no reporting screen holds a reader-facing English literal', () {
    // Words that only ever reach a reader. Slugs, protocol names and example
    // URLs are deliberately English and do not appear here.
    final english = RegExp(
      r'\b(Reports?|Schedules?|Webhooks?|Endpoints?|Templates?|Messages?|'
      r'Announcements?|Recipients?|Delete|Cancel|Refresh|Try again|'
      r'Never run|No .{3,40}\byet|Showing the|Generated|Delivered|'
      r'Not sent|Queued|Retrying|Gave up|Healthy|Unhealthy|Failing|'
      r'attempts?|rows?|photos?|recipients?)\b',
      caseSensitive: true,
    );
    // Dart string literals, single- and double-quoted, on one line.
    final literals = RegExp(
      '\'(?:[^\'\\\\\\n]|\\\\.)*\'|"(?:[^"\\\\\\n]|\\\\.)*"',
    );
    final offenders = <String>[];

    final files = <String>[
      for (final dir in <String>[
        'lib/features/reports/presentation',
        'lib/features/templates/presentation',
        'lib/features/webhooks/presentation',
        'lib/features/collaboration/presentation',
      ])
        for (final f in Directory(dir).listSync().whereType<File>())
          if (f.path.endsWith('.dart')) f.path,
    ];
    expect(files, isNotEmpty);

    for (final path in files) {
      for (final line in File(path).readAsLinesSync()) {
        final code = line.trimLeft();
        // A comment is not something a reader hears.
        if (code.startsWith('//')) continue;
        for (final match in literals.allMatches(line)) {
          // A widget key, a phase name or a provider slug is not something a
          // reader hears. Those are kebab-case or snake_case, with the id
          // interpolated into them; prose is neither.
          final text = match
              .group(0)!
              .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
              .replaceAll(RegExp(r'\$\w+'), '');
          if (text.contains('/') ||
              text.contains('package:') ||
              RegExp(r"^'[a-z0-9-]*'$").hasMatch(text) ||
              RegExp(r"^'[a-z0-9_]*'$").hasMatch(text)) {
            continue;
          }
          if (english.hasMatch(text)) {
            offenders.add('${path.split('/').last}: ${match.group(0)}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Every word a reader hears on these screens comes from the ARB. '
          'A hardcoded English string on a screen whose nav label is already '
          'translated is a defect.',
    );
  });
}

/// One endpoint, so the list renders rather than the empty state.
class _EmptyWebhooksRepository implements WebhooksRepository {
  @override
  Future<PaginatedResponse<Webhook>> listWebhooks() async =>
      const PaginatedResponse<Webhook>(
        data: <Webhook>[
          Webhook(
            id: 'w-1',
            url: 'https://hooks.acme.test/r',
            event: 'visit.submitted',
            active: true,
          ),
        ],
        nextCursor: null,
      );

  @override
  Future<Webhook> createWebhook({
    required String url,
    required String event,
    String? secret,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteWebhook(String id) async => throw UnimplementedError();

  @override
  Future<Webhook> setActive(String id, bool active) async =>
      throw UnimplementedError();

  @override
  Future<List<WebhookDelivery>> listDeliveries(
    String webhookId, {
    int limit = 10,
  }) async => const <WebhookDelivery>[];

  @override
  Future<WebhookDelivery> redeliver(String deliveryId) async =>
      throw UnimplementedError();
}

class _EmptyCollaborationRepository implements CollaborationRepository {
  @override
  Future<PaginatedResponse<Message>> listMessages() async =>
      const PaginatedResponse<Message>(data: <Message>[], nextCursor: null);

  @override
  Future<Message> sendMessage(
    String body, {
    String? recipientId,
    List<String> attachmentPhotoIds = const <String>[],
    String? clientMessageId,
  }) async => throw UnimplementedError();

  @override
  Future<PaginatedResponse<Announcement>> listAnnouncements() async =>
      const PaginatedResponse<Announcement>(
        data: <Announcement>[],
        nextCursor: null,
      );

  @override
  Future<Announcement> createAnnouncement({
    required String title,
    required String body,
  }) async => throw UnimplementedError();
}
