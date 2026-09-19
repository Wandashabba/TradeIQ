import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/template_section_repository.dart';
import 'package:tradeiq_app/features/templates/data/templates_repository.dart';

const _schema = {
  'sections': [
    {
      'id': 'promo',
      'fields': [
        {
          'id': 'standUp',
          'label': 'Stand up?',
          'type': 'boolean',
          'required': true,
        },
        {'id': 'facings', 'label': 'Facings', 'type': 'number'},
      ],
    },
  ],
};

AuditTemplateDetail _detail({int version = 3}) => AuditTemplateDetail(
  template: AuditTemplate(
    id: 'tpl-1',
    name: 'Promo Check',
    version: version,
    active: true,
  ),
  schema: _schema,
);

class _Templates implements TemplatesRepository {
  AuditTemplateDetail? selected;
  bool offline = false;
  int calls = 0;

  @override
  Future<AuditTemplateDetail?> fetchSelected() async {
    calls++;
    if (offline) throw Exception('no signal');
    return selected;
  }

  @override
  Future<PaginatedResponse<AuditTemplate>> listTemplates() =>
      throw UnimplementedError();

  @override
  Future<AuditTemplateDetail> fetchTemplate(String id) =>
      throw UnimplementedError();

  @override
  Future<AuditTemplateDetail?> selectForAudits(String? templateId) =>
      throw UnimplementedError();
}

class _RecordingFlusher implements QueueFlusher {
  final sent = <SyncQueueItem>[];
  bool offline = false;

  @override
  Future<void> flush(SyncQueueItem item) async {
    if (offline) throw Exception('no signal');
    sent.add(item);
  }
}

void main() {
  late LocalDb db;
  late _Templates templates;
  late _RecordingFlusher flusher;
  late DriftTemplateSectionRepository repo;

  setUp(() {
    currentLocalUserId = 'agent-a';
    db = LocalDb(NativeDatabase.memory());
    templates = _Templates();
    flusher = _RecordingFlusher();
    repo = DriftTemplateSectionRepository(
      db: db,
      syncService: SyncService(db: db, flusher: flusher),
      templates: templates,
    );
  });

  tearDown(() async {
    currentLocalUserId = null;
    await db.close();
  });

  Future<ClientTemplate?> pinned(String visitDraftId) async =>
      clientTemplateFrom(
        await (db.select(
          db.pinnedVisitTemplates,
        )..where((t) => t.visitDraftId.equals(visitDraftId))).getSingleOrNull(),
      );

  group('pinning the client template to a visit', () {
    test('pins the selected template with its version, once', () async {
      templates.selected = _detail(version: 3);
      await repo.pinForVisit('v1');

      // The manager edits the template mid-visit: this visit keeps v3.
      templates.selected = _detail(version: 4);
      await repo.pinForVisit('v1');

      final t = await pinned('v1');
      expect(t!.templateId, 'tpl-1');
      expect(t.name, 'Promo Check');
      expect(t.version, 3);
      expect(t.schema.fields.map((f) => f.id), ['standUp', 'facings']);
      expect(templates.calls, 1);
    });

    test('a client without a template pins "none": no section', () async {
      await repo.pinForVisit('v1');
      expect(await pinned('v1'), isNull);
      final rows = await db.select(db.pinnedVisitTemplates).get();
      expect(rows.single.templateId, isNull);
    });

    test(
      'offline, a visit gets the template this agent was last given',
      () async {
        templates.selected = _detail(version: 2);
        await repo.pinForVisit('earlier-visit');

        templates.offline = true;
        await repo.pinForVisit('v2');

        final t = await pinned('v2');
        expect(t?.templateId, 'tpl-1');
        expect(t?.version, 2);
      },
    );

    test(
      'offline with nothing known pins nothing, so a later try can',
      () async {
        templates.offline = true;
        await repo.pinForVisit('v1');
        expect(await db.select(db.pinnedVisitTemplates).get(), isEmpty);
      },
    );

    test(
      'offline never hands one agent another agent’s client questions',
      () async {
        currentLocalUserId = 'agent-b';
        templates.selected = _detail();
        await repo.pinForVisit('b-visit');

        currentLocalUserId = 'agent-a';
        templates.offline = true;
        await repo.pinForVisit('a-visit');

        expect(await pinned('a-visit'), isNull);
      },
    );
  });

  group('saving answers', () {
    ClientTemplate template() => ClientTemplate(
      templateId: 'tpl-1',
      name: 'Promo Check',
      version: 3,
      schemaJson: _schema,
    );

    test(
      'queues a template_response through the outbox and flushes it',
      () async {
        await repo.saveAnswers(
          visitDraftId: 'v1',
          template: template(),
          answers: const {'facings': 4},
        );

        final rows = await db.select(db.syncQueueItems).get();
        expect(rows, hasLength(1));
        expect(rows.single.entityType, templateResponseEntityType);
        expect(rows.single.userId, 'agent-a');
        final payload =
            jsonDecode(rows.single.payloadJson) as Map<String, dynamic>;
        expect(payload, {
          'visitDraftId': 'v1',
          'templateId': 'tpl-1',
          'templateVersion': 3,
          // The untouched switch is recorded as the "off" the agent saw.
          'answers': {'facings': 4, 'standUp': false},
        });
        expect(flusher.sent.single.entityType, templateResponseEntityType);
      },
    );

    test(
      'offline: answers stay queued and read back after an app restart',
      () async {
        flusher.offline = true;
        await repo.saveAnswers(
          visitDraftId: 'v1',
          template: template(),
          answers: const {'standUp': true, 'facings': 2},
        );

        final rows = await db.select(db.syncQueueItems).get();
        expect(rows.single.synced, isFalse);

        // A fresh repository over the same database: nothing is held in memory.
        final reopened = DriftTemplateSectionRepository(
          db: db,
          syncService: SyncService(db: db, flusher: flusher),
          templates: templates,
        );
        expect(
          await reopened.savedAnswers(visitDraftId: 'v1', templateId: 'tpl-1'),
          {'standUp': true, 'facings': 2},
        );
      },
    );

    test(
      'a newer save supersedes an unsent one — one row per section',
      () async {
        flusher.offline = true;
        for (final facings in [1, 2, 3]) {
          await repo.saveAnswers(
            visitDraftId: 'v1',
            template: template(),
            answers: {'facings': facings},
          );
        }
        // Another visit's answers are left alone.
        await repo.saveAnswers(
          visitDraftId: 'v2',
          template: template(),
          answers: const {'facings': 9},
        );

        final rows = await db.select(db.syncQueueItems).get();
        expect(rows, hasLength(2));
        expect(
          await repo.savedAnswers(visitDraftId: 'v1', templateId: 'tpl-1'),
          {'facings': 3, 'standUp': false},
        );
      },
    );

    test('no saved answers reads back empty', () async {
      expect(
        await repo.savedAnswers(visitDraftId: 'v1', templateId: 'tpl-1'),
        isEmpty,
      );
    });
  });
}
